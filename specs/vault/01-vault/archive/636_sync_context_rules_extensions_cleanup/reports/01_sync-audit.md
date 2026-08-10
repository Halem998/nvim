# Research Report: Task #636 — Sync Context, Rules, Extensions Cleanup

**Task**: 636 - sync_context_rules_extensions_cleanup
**Started**: 2026-06-08T00:00:00Z
**Completed**: 2026-06-08T00:45:00Z
**Effort**: ~45 minutes (systematic diff across all categories)
**Dependencies**: Tasks 633, 634, 635 (completed — skills, agents, commands, synthesis-agent ported)
**Sources/Inputs**: find, diff, stat comparisons across .claude/ and .opencode/
**Artifacts**: specs/636_sync_context_rules_extensions_cleanup/reports/01_sync-audit.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- **Rules**: Two top-level rules (`neovim-lua.md`, `nix.md`) are present in `.claude/rules/` but absent from `.opencode/rules/`. They DO exist correctly in `.opencode/extensions/nvim/rules/` and `.opencode/extensions/nix/rules/` — so the question is whether `.opencode/rules/` needs a copy too (mirroring `.claude/rules/`).
- **Context files (stale)**: 74 context files that exist in both `.claude/context/` and `.opencode/context/` differ in content, with `.claude/` being newer (by 1–4 weeks). These need overwrite with the `.claude/` version, with path-prefix substitutions for `.claude/` → `.opencode/` references.
- **Context files (missing)**: The entire `context/project/neovim/` and `context/project/nix/` subtrees (43 files) are missing from `.opencode/context/` — they exist only in `.claude/context/` and the nvim/nix extensions. This is intentional design in `.opencode/` (extension-owned content), but needs analysis.
- **Extension manifests**: All 16 extension manifests differ between `.claude/` and `.opencode/`. The `.opencode/` versions are authoritative for the opencode system — `merge_targets` use `opencode_md`/`AGENTS.md` instead of `claudemd`/`CLAUDE.md`, and `language:` instead of `task_type:`. Several `.claude/` manifests have `hooks:` fields (nvim, nix, core) not present in `.opencode/` versions.
- **status-transitions.md**: Does NOT exist in `.claude/` at all. It exists in three `.opencode/` locations (two are duplicates with minor path-ref differences). No deletion needed in `.claude/`; the `.opencode/context/workflows/` copy may be a stale mirror of `.opencode/extensions/core/context/`.
- **Settings**: `.opencode/settings.json` has meaningful improvements over `.claude/settings.json` (added permissions, timeout values, path fixes) — these should be reviewed and backported to `.claude/settings.json`.
- **Scripts**: 13 shared scripts differ; `.opencode/` has 8 scripts that `.claude/` lacks (new opencode-specific scripts). `.claude/` has several scripts that were removed/consolidated in `.opencode/`.
- **Skills (top-level)**: 4 skills missing from `.opencode/skills/` top-level (`skill-neovim-research`, `skill-neovim-implementation`, `skill-nix-research`, `skill-nix-implementation`).

---

## Context & Scope

This audit compares every file-level component between `.claude/` (source of truth for Claude Code) and `.opencode/` (ported configuration for OpenCode) in the Neovim config repo at `/home/benjamin/.config/nvim/`.

Prior tasks (633-635) ported skills, agents, commands, and synthesis-agent. This task covers the remaining sync items: context files, rules, extension manifests/hooks, stale file cleanup, and settings.

---

## Findings

### 1. Rules

**Top-level rules present in `.claude/rules/` but MISSING from `.opencode/rules/`:**

| File | In `.claude/rules/` | In `.opencode/rules/` | In `.opencode/extensions/` |
|------|--------------------|-----------------------|--------------------------|
| `neovim-lua.md` | YES | NO | YES (extensions/nvim/rules/) |
| `nix.md` | YES | NO | YES (extensions/nix/rules/) |

**Analysis**: In `.claude/`, `rules/neovim-lua.md` and `rules/nix.md` are symlinked or duplicated from the extension rules so they apply at the top level. In `.opencode/`, the extension rules directory IS the canonical location. The `.opencode/rules/` top-level directory does NOT need copies because OpenCode loads extension rules from extension directories directly. This is by design and is NOT a bug.

**Decision**: No action required for rules — the `.opencode/` structure is correct.

**Note**: The rule files themselves (`extensions/nvim/rules/neovim-lua.md` and `extensions/nix/rules/nix.md`) already exist in `.opencode/` and are correct (path references updated from `.claude/` to `.opencode/`).

---

### 2. Context Files — Stale (exist in both, `.claude/` is newer)

All of these exist in `.opencode/context/` with paths matching `.claude/context/` but with older modification dates. The `.claude/` files are consistently 2-5 weeks newer (most were updated 2026-05-13, while `.opencode/` copies date from 2026-05-02 to 2026-05-07).

**Methodology for sync**: Copy `.claude/context/{path}` → `.opencode/context/{path}`, then perform global path substitution: `s/.claude\//.opencode\//g`. Some files have more nuanced differences (see below).

**Complete list of stale context files to overwrite (74 files):**

```
architecture/component-checklist.md       (.claude: 05-13, .opencode: 05-04)
architecture/context-layers.md            (.claude: 05-13, .opencode: 05-04)
architecture/generation-guidelines.md     (.claude: 05-13, .opencode: 05-04)
architecture/system-overview.md           (.claude: 05-22, .opencode: 05-04)
formats/command-output.md                 (.claude: 05-13, .opencode: 05-04)
formats/command-structure.md              (.claude: 05-13, .opencode: 05-04)
formats/frontmatter.md                    (.claude: 05-13, .opencode: 05-04)
formats/handoff-artifact.md               (.claude: 05-13, .opencode: 05-05) *
formats/plan-format.md                    (.claude: 05-13, .opencode: 05-04)
formats/progress-file.md                  (.claude: 05-13, .opencode: 05-04)
formats/roadmap-format.md                 (.claude: 05-13, .opencode: 05-04)
formats/subagent-return.md                (.claude: 05-13, .opencode: 05-04)
formats/summary-format.md                 (.claude: 05-13, .opencode: 05-04)
formats/task-order-format.md              (.claude: 06-01, .opencode: 05-04)
formats/team-metadata-extension.md        (.claude: 05-13, .opencode: 05-04)
guides/extension-development.md           (.claude: 05-13, .opencode: 05-04)
guides/loader-reference.md                (.claude: 05-13, .opencode: 05-04)
index.json                                (.claude: 06-01, .opencode: 05-02) **
index.schema.json                         (.claude: 05-13, .opencode: 05-02)
meta/context-revision-guide.md            (.claude: 06-01, .opencode: 05-04)
meta/domain-patterns.md                   (.claude: 05-13, .opencode: 05-04)
meta/meta-guide.md                        (.claude: 05-13, .opencode: 05-04)
orchestration/architecture.md             (.claude: 06-01, .opencode: 05-04)
orchestration/delegation.md               (.claude: 05-13, .opencode: 05-04)
orchestration/orchestration-validation.md (.claude: 05-13, .opencode: 05-04)
orchestration/orchestrator.md             (.claude: 05-13, .opencode: 05-04)
orchestration/postflight-pattern.md       (.claude: 05-13, .opencode: 05-04)
orchestration/preflight-pattern.md        (.claude: 05-13, .opencode: 05-04)
orchestration/state-management.md         (.claude: 05-13, .opencode: 05-04)
orchestration/subagent-validation.md      (.claude: 05-13, .opencode: 05-04)
orchestration/validation.md               (.claude: 05-13, .opencode: 05-04)
patterns/anti-stop-patterns.md            (.claude: 05-13, .opencode: 05-04)
patterns/artifact-linking-todo.md         (.claude: 06-01, .opencode: 05-04)
patterns/checkpoint-execution.md          (.claude: 05-13, .opencode: 05-04)
patterns/context-discovery.md             (.claude: 05-13, .opencode: 05-04)
patterns/context-exhaustion-detection.md  (.claude: 05-13, .opencode: 05-05) *
patterns/early-metadata-pattern.md        (.claude: 05-13, .opencode: 05-04)
patterns/file-metadata-exchange.md        (.claude: 05-13, .opencode: 05-04)
patterns/inline-status-update.md          (.claude: 06-01, .opencode: 05-04)
patterns/jq-escaping-workarounds.md       (.claude: 05-13, .opencode: 05-04)
patterns/mcp-tool-recovery.md             (.claude: 05-13, .opencode: 05-04)
patterns/metadata-file-return.md          (.claude: 05-13, .opencode: 05-04)
patterns/multi-task-operations.md         (.claude: 06-01, .opencode: 05-04)
patterns/postflight-control.md            (.claude: 05-13, .opencode: 05-04)
patterns/roadmap-update.md                (.claude: 05-13, .opencode: 05-04)
patterns/skill-lifecycle.md               (.claude: 05-22, .opencode: 05-04)
patterns/subagent-continuation-loop.md    (.claude: 05-13, .opencode: 05-05) *
patterns/team-orchestration.md            (.claude: 05-23, .opencode: 05-04)
patterns/thin-wrapper-skill.md            (.claude: 05-22, .opencode: 05-04)
processes/implementation-workflow.md      (.claude: 05-13, .opencode: 05-04)
processes/planning-workflow.md            (.claude: 05-13, .opencode: 05-04)
processes/research-workflow.md            (.claude: 05-13, .opencode: 05-04)
reference/artifact-templates.md           (.claude: 05-13, .opencode: 05-04)
reference/skill-agent-mapping.md          (.claude: 05-22, .opencode: 05-04)
reference/state-management-schema.md      (.claude: 05-22, .opencode: 05-04)
reference/team-wave-helpers.md            (.claude: 05-23, .opencode: 05-04)
reference/workflow-diagrams.md            (.claude: 05-13, .opencode: 05-04)
repo/project-overview.md                  (.claude: 05-13, .opencode: 05-04)
repo/self-healing-implementation-details.md (.claude: 05-13, .opencode: 05-04)
repo/update-project.md                    (.claude: 05-13, .opencode: 05-04)
standards/ci-workflow.md                  (.claude: 05-13, .opencode: 05-04)
standards/documentation-standards.md      (.claude: 05-13, .opencode: 05-04)
standards/error-handling.md               (.claude: 05-13, .opencode: 05-04)
standards/git-safety.md                   (.claude: 05-13, .opencode: 05-04)
standards/interactive-selection.md        (.claude: 05-13, .opencode: 05-04)
standards/postflight-tool-restrictions.md (.claude: 05-13, .opencode: 05-04)
standards/status-markers.md               (.claude: 06-01, .opencode: 05-04)
standards/task-management.md              (.claude: 05-13, .opencode: 05-07)
standards/xml-structure.md                (.claude: 05-13, .opencode: 05-04)
templates/agent-template.md               (.claude: 05-13, .opencode: 05-04)
templates/command-template.md             (.claude: 05-13, .opencode: 05-04)
templates/orchestrator-template.md        (.claude: 05-13, .opencode: 05-04)
templates/subagent-template.md            (.claude: 05-13, .opencode: 05-04)
templates/thin-wrapper-skill.md           (.claude: 05-13, .opencode: 05-04)
troubleshooting/workflow-interruptions.md  (.claude: 05-13, .opencode: 05-04)
workflows/command-lifecycle.md             (.claude: 05-13, .opencode: 05-07)
workflows/preflight-postflight.md          (.claude: 05-13, .opencode: 05-14)
workflows/review-process.md               (.claude: 05-13, .opencode: 05-04)
```

**Files marked `*`**: These files have `.opencode/`-specific content that was already customized (e.g., `handoff-artifact.md` uses a different naming scheme, `context-exhaustion-detection.md` lacks some sections). The `.opencode/` version should be kept as-is OR the file should be synced from `.claude/` with path-prefix substitution only (no semantic merge). Given that `.claude/` is newer and authoritative, recommend sync from `.claude/`.

**File marked `**`**: `index.json` has significant structural differences — `.opencode/index.json` has additional entries (README.md, `core/` subtree entries) and uses `"domain": "core"` fields. This file must NOT be blindly overwritten — it needs a careful merge that preserves `.opencode/`-specific entries while updating stale `.claude/`-origin entries.

---

### 3. Context Files — Missing from `.opencode/context/` (but in `.claude/context/`)

The following files/subtrees exist in `.claude/context/` but are entirely absent from `.opencode/context/`. Most are in `context/project/neovim/` and `context/project/nix/`.

**Analysis**: In `.opencode/`, the neovim and nix context is owned by their respective extensions (`extensions/nvim/context/` and `extensions/nix/context/`) and NOT duplicated in `context/project/`. This is a deliberate architectural decision in `.opencode/` — the content is still available through the extension loader. These files should NOT be copied to `.opencode/context/project/`.

**However**, there are 7 neovim context files missing from `.opencode/extensions/nvim/context/` that are in `.claude/extensions/nvim/context/`:

```
project/neovim/guides/neovim-integration.md        MISSING from .opencode/extensions/nvim/context/
project/neovim/guides/tts-stt-integration.md       MISSING from .opencode/extensions/nvim/context/
project/neovim/hooks/wezterm-integration.md        MISSING from .opencode/extensions/nvim/context/
project/neovim/standards/box-drawing-guide.md      MISSING from .opencode/extensions/nvim/context/
project/neovim/standards/documentation-policy.md  MISSING from .opencode/extensions/nvim/context/
project/neovim/standards/emoji-policy.md           MISSING from .opencode/extensions/nvim/context/
project/neovim/standards/lua-assertion-patterns.md MISSING from .opencode/extensions/nvim/context/
```

**Action**: Copy these 7 files from `.claude/extensions/nvim/context/` to `.opencode/extensions/nvim/context/` (no path changes needed as they reference project content, not system paths).

**Also missing from `.opencode/context/` (misc patterns):**
```
patterns/context-protective-lead.md   (in .claude but NOT in .opencode)
patterns/fork-patterns.md             (in .claude but NOT in .opencode)
```

These exist only in `.claude/context/patterns/` and are absent from `.opencode/context/patterns/`. They should be copied with path-prefix substitution.

---

### 4. Extension Manifests — Hooks

The following extensions have `hooks:` entries in `.claude/` manifests but the corresponding `.opencode/` manifests have `"hooks": {}` or no hooks key:

| Extension | `.claude/` hooks | `.opencode/` hooks |
|-----------|-----------------|-------------------|
| `nvim` | `context_injection: scripts/nvim-context.sh` | `{}` (missing) |
| `nix` | `preflight: scripts/nix-preflight.sh`, `context_injection: scripts/nix-context.sh` | `{}` (missing) |
| `core` | `{}` | `{}` (same) |

**Root cause**: The hook scripts themselves are missing from `.opencode/extensions/nvim/scripts/` and `.opencode/extensions/nix/scripts/`:
- `.claude/extensions/nvim/scripts/nvim-context.sh` → missing from `.opencode/extensions/nvim/scripts/`
- `.claude/extensions/nix/scripts/nix-context.sh` → missing from `.opencode/extensions/nix/scripts/`
- `.claude/extensions/nix/scripts/nix-preflight.sh` → missing from `.opencode/extensions/nix/scripts/`

**Action items**:
1. Copy `nvim-context.sh` from `.claude/extensions/nvim/scripts/` → `.opencode/extensions/nvim/scripts/`
2. Copy `nix-context.sh` and `nix-preflight.sh` from `.claude/extensions/nix/scripts/` → `.opencode/extensions/nix/scripts/`
3. Update `.opencode/extensions/nvim/manifest.json` to add hooks entry: `"hooks": {"context_injection": "scripts/nvim-context.sh"}`
4. Update `.opencode/extensions/nix/manifest.json` to add hooks entry: `"hooks": {"preflight": "scripts/nix-preflight.sh", "context_injection": "scripts/nix-context.sh"}`

**Note**: The hook scripts may reference `.claude/` paths internally — verify and update to `.opencode/` paths before deploying.

---

### 5. Status-transitions.md — Stale/Duplicate Analysis

`status-transitions.md` does NOT exist in `.claude/` anywhere. It exists in three `.opencode/` locations:

1. `.opencode/context/workflows/status-transitions.md` (80 lines)
2. `.opencode/context/core/workflows/status-transitions.md` (86 lines)
3. `.opencode/extensions/core/context/workflows/status-transitions.md` (80 lines)

The three versions differ slightly in cross-reference paths (`status-markers.md` vs `core/standards/status-markers.md`) and in the transition diagram (permissive model vs. explicit diagram).

**Analysis**: This is an `.opencode/`-only file with no `.claude/` counterpart. The task description says to "delete stale `status-transitions.md` from both locations (if applicable)." Since it doesn't exist in `.claude/`, there's nothing to delete there.

For `.opencode/`: The file at `.opencode/context/workflows/status-transitions.md` appears to be a stale copy of the extension-owned canonical at `.opencode/extensions/core/context/workflows/status-transitions.md`. The `core/` subdirectory version (`.opencode/context/core/workflows/`) is also a duplicate.

**Action**: Delete `.opencode/context/workflows/status-transitions.md` (stale flat copy). Keep `.opencode/extensions/core/context/workflows/status-transitions.md` as canonical. Investigate whether `.opencode/context/core/workflows/status-transitions.md` is also a redundant flat copy.

---

### 6. Settings.json Comparison

The `.opencode/settings.json` is MORE up-to-date than `.claude/settings.json`. Key additions in `.opencode/`:

**Permissions added in `.opencode/` (not in `.claude/`):**
- `Bash(nvim *)` — for headless Neovim operations
- `Bash(luac *)` — Lua compiler
- `Bash(pnpm *)` — Node package manager
- `Bash(npx *)` — Node package runner

**Allow list changed in `.opencode/`:**
- `.claude/` has: `TaskCreate`, `TaskUpdate`, `Skill`, `mcp__lean-lsp__*`
- `.opencode/` has: `TodoWrite`, `mcp__lean-lsp__*`, `mcp__astro-docs__*`, `mcp__context7__*`, `mcp__playwright__*`

**Hook improvements in `.opencode/`:**
- Timeout values added to hooks (5000ms, 10000ms for tts-notify)
- `claude-ready-signal.sh` uses absolute path `~/.config/nvim/scripts/`
- All hook paths updated from `.claude/hooks/` to `.opencode/hooks/`
- State file path check improved: `*"state.json"*` → `*"specs/state.json"*` (more precise)

**Action**: The `.opencode/settings.json` improvements (timeouts, extra permissions, improved path specificity) should be reviewed and backported to `.claude/settings.json`. Specifically:
- Add `Bash(nvim *)` and `Bash(luac *)` to `.claude/settings.json`
- Add timeout values to hook entries in `.claude/settings.json`
- Fix state.json path check to use `*"specs/state.json"*` in `.claude/settings.json`

---

### 7. Missing Skills (top-level)

Four skills exist in `.claude/skills/` but are absent from `.opencode/skills/`:

```
skill-neovim-research/SKILL.md
skill-neovim-implementation/SKILL.md
skill-nix-research/SKILL.md
skill-nix-implementation/SKILL.md
```

These DO exist in the extension skill directories:
- `.opencode/extensions/nvim/skills/skill-neovim-research/SKILL.md`
- `.opencode/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`
- `.opencode/extensions/nix/skills/skill-nix-research/SKILL.md`
- `.opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md`

**Analysis**: In `.opencode/`, extension skills live ONLY in extension directories (not duplicated to top-level `skills/`). This matches the `.opencode/` architecture where the extension loader resolves skills from extension directories. No action needed — `.opencode/` design is correct.

---

### 8. Missing Agents (top-level)

Two agents exist in `.claude/agents/` but are absent from `.opencode/agent/subagents/`:
- `neovim-implementation-agent.md`
- `neovim-research-agent.md`
- `nix-implementation-agent.md`
- `nix-research-agent.md`

Same pattern as skills — these are present in extension agent directories (`.opencode/extensions/nvim/agents/` and `.opencode/extensions/nix/agents/`). No action needed.

---

### 9. Extension Manifest Structural Differences (Non-Action Items)

The following manifest differences are CORRECT and expected — they reflect system-specific adaptations already done in prior tasks:

- `"task_type":` in `.claude/` → `"language":` in `.opencode/` (design choice)
- `"merge_targets.claudemd"` → `"merge_targets.opencode_md"` (design choice)
- `"target": ".claude/CLAUDE.md"` → `"target": ".opencode/AGENTS.md"` (system path)
- Removal of `"opencode_json"` merge target (`.opencode/` doesn't use `opencode.json`)
- Epidemiology extension: `.opencode/` uses `epidemiology-research-agent` vs `.claude/` `epi-research-agent` (renamed)
- Memory extension: `.opencode/` uses different Obsidian MCP package (`@dsebastien/obsidian-cli-rest-mcp` vs `@anthropic-ai/obsidian-claude-code-mcp`)

These are intentional and should NOT be reverted.

---

### 10. Scripts Comparison Summary

**13 scripts differ** between `.claude/scripts/` and `.opencode/scripts/` (same file name, different content):
- `command-gate-in.sh`, `command-gate-out.sh`, `command-route-skill.sh`, `dispatch-agent.sh`
- `generate-task-order.sh`, `parse-command-args.sh`
- `postflight-implement.sh`, `postflight-plan.sh`, `postflight-research.sh`, `postflight-workflow.sh`
- `skill-base.sh`
- `update-plan-status.sh`, `update-task-status.sh`

**8 scripts in `.opencode/` not in `.claude/`** (new opencode-specific scripts):
- `check-command-drift.sh`, `update-recommended-order.sh` (core extension additions)
- `execute-command.sh`, `merge-extensions.sh` (opencode-specific)
- `opencode-cleanup.sh`, `opencode-project-cleanup.sh`, `opencode-refresh.sh` (opencode versions of claude-*.sh)
- `test-command.sh`, `test-execution.sh`, `test-execution-system.sh` (test infrastructure)
- `sync-core-commands.sh`, `validate-docs.sh`, `validate-routing-tables.sh` (validation tools)

**Scripts in `.claude/` not in `.opencode/`** (may need porting):
- `archive-task.sh`, `command-gate-in.sh` and others — but `.opencode/` HAS these (they just differ in content)
- Only truly missing from `.opencode/`: `validate-context-budgets.sh`, `vault-operation.sh`, `rename-session.sh`, `roadmap-sync.sh`

**Recommendation**: Script sync is a SEPARATE task from this task's scope. The 13 differing scripts likely have opencode-specific adaptations (path changes) that were done correctly in prior tasks. Do not bulk-overwrite scripts without individual review.

---

### 11. Extension Context Files Missing from `.opencode/` (Summary)

Beyond the nvim context files (Section 3), the following are also missing from `.opencode/` extension directories:

**memory extension** (missing 2 files):
- `context/project/memory/distill-usage.md`
- `context/project/memory/domain/memory-reference.md`

**epidemiology extension** (MAJOR difference — agent/skill rename, full context missing):
- Old `.claude/` agents: `epi-research-agent.md`, `epi-implement-agent.md`
- New `.opencode/` agents: `epidemiology-research-agent.md`, `epidemiology-implementation-agent.md`
- 13 context files and 2 skills exist in `.claude/` but not `.opencode/` (this is a deliberate redesign, not a sync gap)

**filetypes extension** (redesigned — different skills/agents, not a sync gap)

**formal/lean extensions** (missing `context/project/*/standards/literature-fidelity-policy.md` — 2 files)

**python extension** (missing 2 domain files, has 2 different ones)

---

## Decisions

1. **Rules**: No action for top-level rules. The `.opencode/rules/` directory correctly lacks `neovim-lua.md` and `nix.md` because extension rules are loaded from extension directories.
2. **Context (stale)**: Bulk overwrite the 74 stale files from `.claude/context/` with path-prefix substitution. Exception: `index.json` requires careful manual merge.
3. **Context (missing patterns)**: Copy `context-protective-lead.md` and `fork-patterns.md` to `.opencode/context/patterns/`.
4. **Extension hooks**: Add hook scripts and update manifests for nvim and nix extensions.
5. **status-transitions.md**: Delete `.opencode/context/workflows/status-transitions.md` (flat stale copy). Keep extension copy.
6. **Settings**: Backport improvements from `.opencode/settings.json` to `.claude/settings.json` (timeouts, permissions).
7. **Neovim extension context**: Copy 7 missing files from `.claude/extensions/nvim/context/` to `.opencode/extensions/nvim/context/`.
8. **Memory extension context**: Copy 2 missing files to `.opencode/extensions/memory/context/`.

---

## Risks & Mitigations

- **index.json merge risk**: Blindly overwriting `.opencode/context/index.json` would lose `.opencode/`-specific entries (README, core/ subtree references). Mitigation: Use `jq` to merge, preserving `.opencode/`-specific entries and updating matching `.claude/`-origin entries.
- **Hook script path references**: `nvim-context.sh` and `nix-*.sh` may contain `.claude/` path references internally. Mitigation: Run `grep -r '.claude' extensions/nvim/scripts/` after copy and update.
- **Scripts overwrite risk**: Bulk-overwriting the 13 differing scripts could break opencode-specific adaptations. Mitigation: Only sync context and rules in this task; leave scripts for a separate focused review.
- **`status-transitions.md` deletion**: Deleting without checking if it's referenced. Mitigation: `grep -r 'status-transitions' .opencode/` before deletion.

---

## Context Extension Recommendations

None (meta task type — omitted per standards).

---

## Appendix

### File Counts

| Category | Count | Action |
|----------|-------|--------|
| Stale context files | 74 | Overwrite from .claude (with path subs) |
| Missing context files (nvim ext) | 7 | Copy from .claude/extensions/nvim/context/ |
| Missing context files (patterns) | 2 | Copy from .claude/context/patterns/ |
| Missing context files (memory ext) | 2 | Copy from .claude/extensions/memory/context/ |
| Missing hook scripts | 3 | Copy from .claude/extensions/ |
| Manifest hooks to add | 2 | nvim and nix manifests |
| Files to delete | 1 | .opencode/context/workflows/status-transitions.md |
| Settings improvements | Several | Backport from .opencode → .claude |

### Search Queries Used
- `find .claude -type f | sort`
- `find .opencode -type f | sort`
- `diff .claude/settings.json .opencode/settings.json`
- `for ext in ...; do diff .claude/extensions/$ext/manifest.json .opencode/extensions/$ext/manifest.json; done`
- `comm -23 <(find .claude/context ...) <(find .opencode/context ...)` for all context categories
- `stat -c '%Y' ...` for modification time comparisons
