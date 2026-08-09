# Research Report: Task #873

**Task**: 873 - Add global-default target resolution and `--local` flag to `/meta`
**Started**: 2026-07-15T00:00:00Z
**Completed**: 2026-07-15T10:23:00-07:00
**Effort**: Medium (3 files, documentation + one flag + one `cd`-based resolution block)
**Dependencies**: None (this task establishes the mechanism task 875 consumes)
**Sources/Inputs**: Codebase (agent-system/extensions/core/**, lua/neotex/plugins/ai/claude/**, ~/.claude/settings.json, ~/.dotfiles/config/claude/settings.json, sampled project `.claude/settings.json` files), WebSearch (Claude Code subagent cwd behavior, permissions model)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **(a) Permission/sandbox risk is NOT a blocker.** Every sampled `.claude/settings.json` in
  this environment — the Home-Manager-managed global `~/.claude/settings.json`
  (`~/.dotfiles/config/claude/settings.json`) and every per-repo deployed copy checked
  (cslib, BimodalHarness, BimodalLogic, cslib-refactor-prop_logic, Literature, ModelBuilder,
  ModelChecker) — grants bare, path-unscoped `"Write"`, `"Edit"`, and `"Bash(cd *)"` in its
  `allow` list. None uses a glob-scoped form (`Write(src/**)`) that would restrict writes to
  the project root. There is live production precedent for exactly this cross-repo write
  pattern already: `literature-ingest.sh` (invoked from any repo via `--lit`) unconditionally
  `mkdir -p`s and writes `metadata.json`/`index.json` into `$LITERATURE_DIR`
  (`~/Projects/Literature`), a location outside the invoking repo, with no reported friction.
  The `--local` opt-out design is still correct policy (respect the possibility of a future
  more-restrictive project override), but the current settings posture does not require it
  for feasibility.
- **(b) `CLAUDE_AGENT_GLOBAL_ROOT` (shell) and `global_source_dir` (Lua) are, and should
  remain, two independently-resolved defaults that happen to agree on `~/.config/nvim`, not
  one coupled value.** Neovim/Lua cannot read a bash-only env var set inside a Claude Code
  session's shell subprocess (they are different processes with no shared IPC), and vice
  versa — so literal single-source-of-truth coupling is not achievable without new
  infrastructure, which is out of scope (edit targets are frozen to the 3 named files; the two
  Lua files are not in `file_scope`). The recommended mitigation is **documentation-only**:
  state explicitly, in `commands/meta.md`, that the two defaults are deliberately parallel and
  must be changed together if either is ever overridden. A low-cost follow-up (not this task)
  is noted: `scan.lua`/`config.lua` could additionally check
  `vim.fn.getenv("CLAUDE_AGENT_GLOBAL_ROOT")` before falling back to the hardcoded
  `~/.config/nvim`, closing the drift risk without touching CLAUDE_PROJECT_DIR or the 49
  scripts.
- **(c) The git postflight commit lands in the right repo only if `GLOBAL_ROOT` is re-derived
  (or the `cd` re-issued) at every bash call site that needs it — not if a single early `cd`
  is assumed to persist across the whole multi-turn `/meta` flow.** Claude Code's Bash tool
  state (including cwd) does **not** persist across separate Bash tool invocations for
  Task-tool-spawned subagents (confirmed by both this repo's own
  `parse-command-args.sh` convention — "source within a single Bash tool invocation... variables
  visible to subsequent commands in that same invocation" — and external evidence: GitHub
  issue #12748 documents that subagents must prefix every Bash command with `cd /path &&`
  because they do not retain a prior `cd`). `skill-meta` itself executes inline in the
  invoking (root) session and so benefits from normal within-session cwd persistence for its
  *own* sequential Bash calls, but the interactive interview spans many intervening tool calls
  (including an Agent-tool spawn of `meta-builder-agent`, a genuinely separate subagent
  context), so the safe, defense-in-depth design is: re-run `GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"` and `cd "$GLOBAL_ROOT" && ...` as a single chained Bash
  invocation at (i) the point tasks are created and (ii) the postflight `git add specs/ &&
  git commit`, rather than relying on a `cd` issued many turns earlier. PreToolUse/PostToolUse
  hooks (`guard-destructive-git.sh`, `validate-meta-write.sh`) run outside the agent's Bash
  subprocess at the harness's own session cwd, not the agent's `cd`'d location — this matters
  for `guard-destructive-git.sh` (which runs `git status --porcelain` against whatever its own
  cwd is) but not for `validate-meta-write.sh` (pure path-string matching, cwd-agnostic, and
  matches correctly on absolute paths).

## Context & Scope

Task 873 defines the global-default resolution mechanism for `/meta`: a `cd "$GLOBAL_ROOT"`
step plus a `--local` opt-out flag, scoped to exactly three files under
`agent-system/extensions/core/`: `commands/meta.md`, `skills/skill-meta/SKILL.md`, and
`scripts/parse-command-args.sh`. Task 875 (dependent, not in scope here) updates
`meta-builder-agent.md` to operate correctly once this root is resolved and threaded through.
This report answers the three feasibility questions the task description flags as MUST-SETTLE,
and does not redesign the chosen `cd` mechanism, introduce `CLAUDE_PROJECT_DIR`, or touch the
~49 scripts.

## Findings

### Codebase Patterns

**Existing flag convention (parse-command-args.sh, full file read)**: `--clean` and `--force`
are implemented as an `[[ "$remaining" =~ --clean ]]` regex match at line 103 setting
`CLEAN_FLAG="true"`, and correspondingly stripped from `FOCUS_PROMPT` via
`sed 's/--clean//g'` at line 129. `--local` should follow this exact shape: add
`LOCAL_FLAG="false"` to the Step 4 initializer block (near line 75), add
`if [[ "$remaining" =~ --local ]]; then LOCAL_FLAG="true"; fi` alongside the other flag checks
(around line 106-117), add `LOCAL_FLAG` to the exported-variables header comment (line 19-22
region) and the `export` statement (line 142), and add `sed 's/--local//g'` to the
`FOCUS_PROMPT` strip pipeline (around line 129-133). One nuance: `/meta` is not currently in
the set of commands that source `parse-command-args.sh` for task-number parsing (it takes a
free-form prompt/`--analyze`, not `N[,N-N]`), so `--local` detection for `/meta` most likely
needs its own lightweight regex check inline in `commands/meta.md`'s Mode Detection step (or
skill-meta's Input Validation step) rather than (or in addition to) sourcing the full
`parse_command_args` function, unless the task intends to normalize `/meta`'s argument parsing
onto the shared script for consistency. Since the task's edit target list explicitly includes
`scripts/parse-command-args.sh`, adding `LOCAL_FLAG` there in the shared/superset style is
still correct even if `/meta`'s own mode-detection block also needs a same-shaped standalone
check — the shared script remains the canonical single definition other commands can pick up.

**`commands/meta.md`** (full file read, 237 lines): Mode Detection (Execution step 1, lines
57-69) currently only branches on empty/`--analyze`/prompt. This is the natural place to
resolve `GLOBAL_ROOT` and detect `--local`, before delegating to `skill-meta`. The Anti-Bypass
Constraint section (lines 34-53) already establishes the "writes to `specs/` are legitimate
writes to `.claude/` are forbidden" boundary — global-mode resolution doesn't change that
boundary, only which repo's `specs/` is the legitimate target. The `argument-hint` frontmatter
(line 4, currently `"[PROMPT] | --analyze"`) needs `--local` added per task instructions.

**`skills/skill-meta/SKILL.md`** (full file read, 265 lines): Section 1 "Input Validation"
(lines 44-64) is a bash-fenced mode-detection block already — this is the natural site for
`GLOBAL_ROOT` resolution and the `cd`. Section 2 "Context Preparation" (lines 68-81) builds the
JSON delegation context passed to `meta-builder-agent` via the Agent tool (Section 3) — this is
where the resolved `mode`/`root` must be threaded through per the task description, consumed by
task 875's `meta-builder-agent.md` changes. The skill's own postflight (referenced at line 13
and the "MUST NOT" section's closing note, lines 233-236: "The postflight phase is LIMITED TO:
Reading agent return, Git commit (if tasks were created)") does not currently contain literal
git commands — this SKILL.md is the layer that needs the concrete
`GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"` + `cd` + `git add specs/ && git
commit` sequence added as an explicit bash block, mirroring `skill-git-workflow/SKILL.md`'s
"Task Commit" execution command (`git add specs/` then `git commit`, with no `-C` or repo
qualifier — meaning correctness depends entirely on process cwd at call time).

**Two path-resolution strategies already coexist** (confirmed via the task description and
spot-checked): Strategy A (script-location-relative, e.g. `update-task-status.sh:255` does
`cd "$PROJECT_ROOT"` after computing `PROJECT_ROOT` from `$SCRIPT_DIR/../..`) and Strategy B
(bare relative, CWD-following, e.g. `skill-git-workflow`'s literal `git add specs/` /
`git commit` commands, and the PreToolUse hook `guard-destructive-git.sh`'s bare
`git status --porcelain`). The task's chosen `cd "$GLOBAL_ROOT"` mechanism is verified sound
for Strategy A (a script invoked via `bash .claude/scripts/foo.sh` from within a `cd`'d shell
resolves its own `$SCRIPT_DIR`-relative `PROJECT_ROOT` correctly regardless of caller cwd) and
for Strategy B *only within the same Bash tool invocation the `cd` was issued in* (see Finding
(c) below for why this qualifier matters).

**Lua-side global_source_dir** (`lua/neotex/plugins/ai/claude/config.lua:40-41`):
```lua
-- Global source directory for artifact syncing
global_source_dir = vim.fn.expand("~/.config/nvim"),
```
consumed by `M.setup(opts)` via `vim.tbl_deep_extend`, and independently re-derived with its
own identical hardcoded fallback at
`lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua:8-17`
(`M.get_global_dir()`, tries `config.options.global_source_dir`, then
`config.defaults.global_source_dir`, then falls back to `vim.fn.expand("~/.config/nvim")`
directly). Six other call sites (`parser.lua:721`, `entries.lua` x7, `previewer.lua:39`) all
route through `scan.get_global_dir()` or the `config.global_source_dir or scan.get_global_dir()`
pattern — i.e. there is already a well-established single Lua-side accessor function, just no
env-var awareness in it. `lua/neotex/plugins/ai/shared/picker/config.lua` has three more
independent `vim.fn.expand("~/.config/nvim")` hardcodes (lines 49, 71, 90) for a sibling
picker config schema — these are outside this task's file_scope and outside the Lua files named
in the task description, but are relevant context for any future consolidation.

### External Resources

- GitHub issue [anthropics/claude-code#12748](https://github.com/anthropics/claude-code/issues/12748)
  ("Add cwd parameter to Task tool for setting subagent working directory") confirms the
  current-as-of-2026 behavior: "Subagents inherit the parent's PWD and need to prefix every
  Bash command with `cd /path &&`" — i.e. a `cd` issued in one Bash tool call inside a subagent
  does not carry forward to the subagent's next Bash tool call; each call resets to the
  inherited launch cwd.
- GitHub issue [anthropics/claude-code#33576](https://github.com/anthropics/claude-code/issues/33576)
  ("Sub-agents Bash tool defaults to /root instead of inheriting parent session's working
  directory") documents a known reliability bug in that inheritance-at-spawn step itself — an
  upstream risk outside this task's control, worth a one-line residual-risk note but not a
  blocker (it is a bug in the *intended* behavior, which is that subagents should inherit the
  parent's cwd at spawn time; when the bug doesn't trigger, inheritance works as designed).
- [code.claude.com/docs/en/permissions](https://code.claude.com/docs/en/permissions): Write/Edit
  path rules are glob-pattern-based (`Write(src/**)` scopes; bare `Write` is unscoped/global);
  rule evaluation order is deny -> ask -> allow, first match wins. This confirms the settings.json
  audit finding above is not an accident of a stale template — it is the documented mechanism
  by which unscoped `Write`/`Edit` grants blanket path access.

### Recommendations

**(a) Permission/sandbox — proceed as designed, no extra gating needed.** The `--local`
opt-out remains valuable as user-facing intent control (and as insurance against a future
tightened settings.json), but implementation should not add defensive permission-probing logic
(e.g. a pre-flight "can I write here" check) since current settings already grant unconditional
Write/Edit/Bash(cd) across every sampled repo. If `commands/meta.md` documents this assumption,
note it as: "Global-mode writes rely on Write/Edit being unscoped (no `Write(path/**)` narrowing)
in the effective settings.json; a project that scopes Write more tightly would need to add
`GLOBAL_ROOT` to its own settings' allowed paths."

**(b) GLOBAL_ROOT / global_source_dir — document as parallel defaults, do not couple.** Add an
explicit note (in `commands/meta.md`, e.g. near the Mode Detection section) stating that
`CLAUDE_AGENT_GLOBAL_ROOT` (shell, consumed by `/meta`'s resolution) and `global_source_dir`
(Lua, `lua/neotex/plugins/ai/claude/config.lua:40-41`, consumed by the `<leader>al`
picker/loader) are independently-resolved values that share the same default
(`~/.config/nvim`) by convention, not by mechanism, and must be updated together if either is
customized. Do not add code to either runtime to read the other's value in this task (out of
`file_scope`); flag the `scan.lua`/`config.lua` env-var-awareness enhancement
(`vim.fn.getenv("CLAUDE_AGENT_GLOBAL_ROOT")` fallback chain) as a candidate follow-up task, not
a requirement of 873.

**(c) Git postflight commit — chain, don't rely on distant persistence.** In
`skills/skill-meta/SKILL.md`, resolve `GLOBAL_ROOT` once in prose/variable terms early
(Section 1, for documentation/readability), but write the *actual* postflight git commands as
a single chained Bash invocation that re-derives and re-`cd`s at the point of execution:
```bash
GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"
cd "$GLOBAL_ROOT" && git add specs/ && git commit -m "$(cat <<'EOF'
task {N}: create {title}
EOF
)"
```
in one Bash tool call, matching the existing `parse-command-args.sh` convention of doing
everything state-dependent within a single invocation. Apply the same chaining discipline to
whatever bash calls `skill-meta`/`meta-builder-agent` issue for task-directory creation
(`mkdir -p specs/{NNN}_{SLUG}/{reports,plans,summaries}`, `generate-todo.sh`,
`update-task-status.sh`) in local (non-global) mode this is a no-op since `GLOBAL_ROOT` resolves
to the current repo already (satisfying the task's stated no-op requirement for `/meta` invoked
from within `~/.config/nvim`). For Write/Edit tool calls specifically (which are separate from
Bash and have their own path semantics, not subject to shell cwd at all — they take the literal
path string given), use paths qualified by `$GLOBAL_ROOT` explicitly (or absolute) rather than
bare `specs/...`, since Write/Edit path resolution is independent of any Bash-side `cd` and does
not benefit from it at all — this is a distinct, stricter requirement than the git-commit cwd
question and applies uniformly to both `skill-meta` and (per task 875) `meta-builder-agent`.

## Decisions

- `--local` should be added to `parse-command-args.sh` in the established regex-match +
  sed-strip shape (mirroring `--clean`/`--force`), even though `/meta` itself may need a
  lighter-weight inline check for its free-form argument grammar; the shared script remains the
  canonical definition.
- No permission pre-check or `additionalDirectories` configuration is needed for this task —
  current settings.json posture (verified across 8+ repos plus the global Home-Manager source)
  already grants unscoped Write/Edit/Bash(cd) everywhere sampled.
- `CLAUDE_AGENT_GLOBAL_ROOT` and Lua's `global_source_dir` are documented as parallel, not
  coupled; no Lua file edits are in scope for 873.
- The postflight git commit (and any other bash step that depends on `GLOBAL_ROOT`) must
  re-derive `GLOBAL_ROOT` and chain `cd "$GLOBAL_ROOT" && ...` within a single Bash tool
  invocation at the point of use, rather than relying on an earlier, separately-invoked `cd`
  to persist across the multi-turn interactive flow or across the Agent-tool subagent boundary.

## Risks & Mitigations

- **Risk**: A future project could tighten its `.claude/settings.json` to scope `Write`/`Edit`
  to project-relative globs, breaking global-mode `/meta` writes with permission-ask friction.
  **Mitigation**: `--local` already provides the opt-out; document the settings dependency so a
  future tightening is a conscious, informed choice.
- **Risk**: Upstream Claude Code bug (#33576) where subagent Bash cwd inheritance-at-spawn
  itself can misfire (defaulting to `/root` instead of the parent's cwd). **Mitigation**: none
  available within this task's scope; this is an upstream reliability risk to note, not fix.
  Since `meta-builder-agent`'s bash/Write calls should use `$GLOBAL_ROOT`-qualified or absolute
  paths per the (c) recommendation regardless, this bug's blast radius is reduced to
  ambient-cwd-relative bash scripts specifically (Strategy B scripts), not to Write/Edit calls.
- **Risk**: `guard-destructive-git.sh` (PreToolUse hook on Bash) evaluates `git status
  --porcelain` at the *harness's* session cwd (the original launch repo), not the agent's `cd`'d
  location, for destructive git commands. This does not block plain `git commit` (not in its
  guarded pattern list), so it does not affect this task's postflight commit, but any future
  destructive git operation issued against `$GLOBAL_ROOT` from within a `cd`'d Bash subprocess
  should not assume the guard is evaluating the right repo's dirty-state. Out of scope for 873;
  noted for awareness.

## Context Extension Recommendations

- **Topic**: Cross-runtime default coupling (shell env var vs. Lua config option)
- **Gap**: No existing context file documents the "parallel defaults, not coupled" pattern now
  established between `CLAUDE_AGENT_GLOBAL_ROOT` and `global_source_dir`. The `LITERATURE_DIR`
  precedent is shell-only (no Lua-side counterpart), so this is a new pattern shape.
- **Recommendation**: If a comparable shell/Lua paired-default pattern recurs elsewhere, capture
  it as a pattern doc under `.claude/context/patterns/` (e.g.
  `cross-runtime-default-coupling.md`); premature to create for a single instance.

## Appendix

**Files read in full**: `agent-system/extensions/core/commands/meta.md`,
`agent-system/extensions/core/skills/skill-meta/SKILL.md`,
`agent-system/extensions/core/scripts/parse-command-args.sh`,
`agent-system/extensions/core/skills/skill-git-workflow/SKILL.md`,
`agent-system/extensions/core/hooks/guard-destructive-git.sh`,
`agent-system/extensions/core/hooks/validate-meta-write.sh`.

**Files spot-read**: `lua/neotex/plugins/ai/claude/config.lua` (1-60),
`lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` (1-40),
`agent-system/extensions/literature/scripts/literature-ingest.sh` (grep + spot lines),
`~/.claude/settings.json`, `~/.dotfiles/config/claude/settings.json`,
`~/Projects/{cslib,BimodalHarness,BimodalLogic,cslib.bak,cslib-refactor-prop_logic,
Literature,ModelBuilder,ModelChecker}/.claude/settings.json`.

**Searches performed**: `grep global_source_dir` across `lua/`; `grep "cd \""` across skills
and scripts; WebSearch "Claude Code Task tool subagent working directory cwd inherit parent
2026"; WebSearch "Claude Code permissions file write outside project directory allow deny
settings.json".

**Related task**: 875 (dependent — updates `meta-builder-agent.md` to consume the root this task
resolves; not researched here beyond confirming the scope boundary via its state.json
description).
