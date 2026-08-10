# Research Report: OpenCode Lean Routing Failure Diagnosis

- **Task**: 572 - diagnose_opencode_lean_routing_failure
- **Started**: 2026-05-14T16:40:00Z
- **Completed**: 2026-05-14T16:56:27Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Sources/Inputs**:
  - `/home/benjamin/.config/nvim/.opencode/output/implement.md` — Failing session output trace
  - `/home/benjamin/Projects/ProofChecker/.opencode/commands/implement.md` — Buggy command definition
  - `/home/benjamin/.config/nvim/.opencode/commands/implement.md` — Fixed command definition (nvim)
  - `/home/benjamin/Projects/ProofChecker/.opencode/extensions/lean/manifest.json` — Lean extension manifest
  - `/home/benjamin/Projects/ProofChecker/.opencode/extensions.json` — Extension installation state
  - `/home/benjamin/Projects/ProofChecker/opencode.json` — Project-level agent registration
  - `/home/benjamin/Projects/ProofChecker/.opencode/skills/skill-lean-implementation/SKILL.md` — Skill definition
  - `diff` comparison of ProofChecker vs nvim implement.md, research.md, plan.md
  - All child project implement.md files: dotfiles, OpenCode, Zed, ModelChecker, protocol
- **Artifacts**:
  - `specs/572_diagnose_opencode_lean_routing_failure/reports/01_opencode-routing-diagnosis.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

---

## Executive Summary

- **Root cause confirmed**: OpenCode's Glob tool silently returns 0 results for relative paths starting with `.opencode/` (hidden directory prefix), causing extension manifest discovery to fail universally in child projects
- **Immediate cause**: ProofChecker's `implement.md` uses an unfixed relative path `for manifest in .opencode/extensions/*/manifest.json` rather than the project-root-anchored absolute path added in the nvim config fix
- **Scope is wider than ProofChecker**: All 5 other child projects (dotfiles, OpenCode project, Zed, ModelChecker, protocol) also contain the buggy routing code — every extension-typed task in any of these projects routes to `skill-implementer` regardless of task type
- **Structural gap**: There is no propagation mechanism for core command updates (implement.md, research.md, plan.md); these files were fixed in the nvim config but never copied to child projects
- **Extension installation was correct**: The lean extension was properly installed in ProofChecker (skills, agents, manifests, context all present) — only the routing discovery mechanism was broken
- **Secondary issues**: All child project commands are outdated versions missing improvements such as the COMMAND EXECUTION MODE preamble, delegation chain notes, plan-file-as-primary-truth logic, and manifest count warning

---

## Context & Scope

### What Was Investigated

The user ran `/implement 129` in `/home/benjamin/Projects/ProofChecker/`, a project with task type `lean4`. The command spawned `general-implementation-agent` instead of `lean-implementation-agent`. The failing session output was captured at `~/.config/nvim/.opencode/output/implement.md`.

Research investigated:
1. The exact failure point in the routing chain
2. Whether the lean extension was properly installed
3. Why the Glob tool returned no results despite extension manifests existing
4. The scope of the bug across all child projects
5. Other structural issues found during investigation

### Constraints

- This is a meta task — no code changes made, diagnostic only
- The failing session is now complete; analysis is retrospective
- Timing: lean extension was installed at 09:38:35 local time, `/implement` ran at 09:43:26 (5 minutes later)

---

## Findings

### Finding 1: Root Cause — OpenCode Glob Tool Cannot Search Hidden Directories via Relative Paths

The session output at line 484 shows:

```
✱ Glob ".opencode/extensions/*/manifest.json"
```

This call returned **zero results** even though `/home/benjamin/Projects/ProofChecker/.opencode/extensions/lean/manifest.json` existed at that time (confirmed by file modification timestamp 09:38:35, before the command ran at 09:43:26).

The same session successfully ran:
```
✱ Glob "specs/129_*/plans/*.md" (3 matches)
```

The contrast is definitive: relative paths pointing into non-hidden directories work; relative paths starting with `.opencode/` (a hidden directory, prefixed with `.`) return no results. This is a Glob tool limitation in OpenCode's implementation.

The nvim config's `implement.md` was **already fixed** for this exact issue by adding:

```bash
project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
manifest_dir="$project_root/.opencode/extensions"
for manifest in "$manifest_dir"/*/manifest.json; do
```

Using absolute paths bypasses the hidden-directory limitation. The LLM derives the absolute path via Bash (using `git rev-parse`), then calls Glob with a full absolute path.

### Finding 2: The ProofChecker implement.md Contains the Unfixed Routing Code

ProofChecker's `implement.md` (at `.opencode/commands/implement.md`) still uses:

```bash
for manifest in .opencode/extensions/*/manifest.json; do
```

This is the pre-fix version. There are 12 additional lines in the nvim version including the `project_root`/`manifest_dir` setup, the `manifest_count` counter with a warning when no manifests found, and updated extension skills location documentation.

The ProofChecker's `research.md` and `plan.md` have the same unfixed routing code.

### Finding 3: All Other Child Projects Also Have the Bug

Every child project's routing commands are outdated:

| Project | implement.md | research.md | plan.md |
|---------|-------------|-------------|---------|
| ProofChecker | BUG | BUG | BUG |
| dotfiles | BUG | — | — |
| OpenCode project | BUG | — | — |
| Zed | BUG | — | — |
| ModelChecker | BUG | — | — |
| protocol | BUG | — | — |
| nvim (source) | **FIXED** | **FIXED** | **FIXED** |

This means **any task with an extension type** (`lean4`, `lean`, `latex`, `typst`, `nix`, `python`, `formal`, `logic`, etc.) will silently fall back to `skill-implementer` (and then `general-implementation-agent`) in all child projects.

### Finding 4: No Core Command Propagation Mechanism

The extension loader (`shared/extensions/loader.lua`) copies extension-provided files (agents, skills, rules, context, commands from `extensions/{name}/commands/`) to child projects when extensions are loaded or reloaded. However, **core system commands** (`implement.md`, `research.md`, `plan.md`, `task.md`, etc.) in `.opencode/commands/` are not managed by the extension system — they are set up once during initial project configuration and never automatically updated.

The fix applied to `nvim/.opencode/commands/implement.md` must be manually propagated to each child project. No automated sync exists.

### Finding 5: Extension Installation Was Correct in ProofChecker

The lean extension was properly installed via the extension loader on 2026-05-14T16:38:35Z. The following files were correctly placed:

- `.opencode/agent/subagents/lean-research-agent.md` ✓
- `.opencode/agent/subagents/lean-implementation-agent.md` ✓
- `.opencode/commands/lake.md`, `lean.md` ✓
- `.opencode/rules/lean4.md` ✓
- `.opencode/skills/skill-lean-research/SKILL.md` ✓
- `.opencode/skills/skill-lean-implementation/SKILL.md` ✓
- `.opencode/skills/skill-lake-repair/SKILL.md` ✓
- `.opencode/skills/skill-lean-version/SKILL.md` ✓
- `.opencode/context/project/lean4/` (full directory) ✓
- `.opencode/extensions/lean/manifest.json` (stub for routing discovery) ✓

The extension installation chain is not the problem.

### Finding 6: The lean-implementation-agent Is Registered and Available

The lean implementation agent is registered in ProofChecker's `opencode.json` as `"lean-implementation"` with the prompt pointing to `.opencode/agent/subagents/lean-implementation-agent.md`. The skill uses `subagent_type: "lean-implementation-agent"` (with `-agent` suffix). OpenCode resolves this by file-based agent discovery from `.opencode/agent/subagents/lean-implementation-agent.md` — the naming works consistently, confirmed by `general-implementation-agent` being successfully spawned via the same pattern in the failure trace.

### Finding 7: Outdated Routing Tables in Child Project Commands

All child projects with the buggy routing code also contain **hardcoded extension routing tables** that are now outdated:

```
| `founder` | `skill-founder-implement` (from founder extension) |
| `formal`, `logic`, `math`, `physics` | `skill-implementer` (default) |
```

The nvim version replaced these tables with: "The bash discovery code above is the authoritative runtime mechanism; no hardcoded tables are used." The hardcoded tables are incomplete and may mislead the LLM about available routing.

### Finding 8: All Child Commands Missing COMMAND EXECUTION MODE Preamble

The nvim versions of all commands now include:

```
> **COMMAND EXECUTION MODE** — You have been invoked as this command with arguments: `$ARGUMENTS`. Execute the workflow below immediately.
```

This preamble is absent from all child project commands. Its absence may contribute to the LLM pausing to describe the command rather than executing it.

### Finding 9: ProofChecker Lean Extension Stub Is Incomplete

The lean extension stub at `.opencode/extensions/lean/manifest.json` in ProofChecker contains only `manifest.json` (no `EXTENSION.md`, no `skills/` subdirectory, no `agents/`, etc.). This is by design — the extension loader copies all files to their runtime locations and only keeps the manifest as a reference for routing discovery. The stub design is intentional and correct for the routing purpose.

---

## Decisions

- The routing failure is definitively caused by the unfixed relative-path Glob in ProofChecker's `implement.md` (and same pattern in `research.md`, `plan.md`)
- The fix (absolute path via `project_root`) from nvim's implement.md is the correct solution
- All 5 other child projects require the same fix applied to their `implement.md`, `research.md`, and `plan.md`
- A command sync mechanism should be created to prevent recurrence

---

## Recommendations

### Priority 1 (Immediate): Fix Routing in All Child Projects

Apply the project_root absolute-path fix to `implement.md`, `research.md`, and `plan.md` in all affected projects:

- `/home/benjamin/Projects/ProofChecker/.opencode/commands/`
- `/home/benjamin/.dotfiles/.opencode/commands/`
- `/home/benjamin/Projects/OpenCode/.opencode/commands/`
- `/home/benjamin/.config/zed/.opencode/commands/`
- `/home/benjamin/Projects/ModelChecker/.opencode/commands/`
- `/home/benjamin/Projects/protocol/.opencode/commands/`

For each affected command, replace:
```bash
for manifest in .opencode/extensions/*/manifest.json; do
```
with:
```bash
project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
manifest_dir="$project_root/.opencode/extensions"
manifest_count=0
for manifest in "$manifest_dir"/*/manifest.json; do
    manifest_count=$((manifest_count + 1))
```
And add after both loops:
```bash
if [ "$manifest_count" -eq 0 ]; then
  echo "[WARN] No extension manifests found in $manifest_dir."
fi
```

### Priority 2 (Short-term): Create a Core Command Sync Script

Create a script (`.opencode/scripts/sync-core-commands.sh`) that copies the canonical versions of `implement.md`, `research.md`, `plan.md`, and other core commands from the nvim config to all registered child projects. This script should:
- Accept a list of target project directories (or read from a registry file)
- Copy with validation (confirm the target file has the expected structure)
- Log what was updated
- Be idempotent

### Priority 3 (Short-term): Add COMMAND EXECUTION MODE Preamble to All Child Commands

All child project commands (not just routing commands) are missing the execution preamble. These should be updated in batch. The preamble is:
```
> **COMMAND EXECUTION MODE** — You have been invoked as this command with arguments: `$ARGUMENTS`. Execute the workflow below immediately. Do not summarize this file, ask what to do with it, or describe its contents. Start execution now.
```

### Priority 4 (Medium-term): Task Type Validation Warning

Add a check in `implement.md`, `research.md`, and `plan.md` that warns when a non-default task type is detected but no extension routing was found. This would surface routing failures explicitly instead of silently falling back:

```bash
if [ "$manifest_count" -gt 0 ] && [ -z "$skill_name" ] && [ "$task_type" != "general" ] \
   && [ "$task_type" != "meta" ] && [ "$task_type" != "markdown" ]; then
  echo "[WARN] No extension routing found for task_type='$task_type'. Falling back to skill-implementer."
fi
```

### Priority 5 (Medium-term): Consider Extension Loader Integration for Core Commands

Evaluate whether core commands should be managed as part of an extension (the `core` extension) so the extension loader can update them when extensions are reloaded. This would automate propagation of fixes.

---

## Risks & Mitigations

- **Ongoing silent misdirection**: Until fixed, every lean4, nix, formal, and other extension-typed task in child projects silently routes to general-implementation-agent. The general agent may attempt the work but lacks domain-specific tools, context, and lean-lsp MCP integration.
- **Data integrity in ongoing tasks**: Task 129 in ProofChecker is `[IMPLEMENTING]`. The wrong agent ran Phase 1 and may have made incorrect changes. These changes should be reviewed before resuming with the correct lean-implementation-agent.
- **Fix scope verification**: After applying the routing fix to child projects, verify by running a dry-run of the routing logic (without full implementation) to confirm manifests are discovered correctly.

---

## Context Extension Recommendations

- **Topic**: OpenCode child project command lifecycle
- **Gap**: No documentation exists on how core commands (implement.md, research.md, plan.md) are propagated to or maintained in child projects. The extension system documentation covers extension-provided files but not core system commands.
- **Recommendation**: Create `.opencode/context/patterns/child-project-command-sync.md` documenting the architecture decision (core commands are manually maintained), the known divergence risk, and the recommended sync script approach.

---

## Appendix

### Failure Chain Summary

```
User: /implement 129 (task_type=lean4) in ProofChecker
  -> implement.md (ProofChecker version, unfixed) loaded
  -> STAGE 2: Glob(".opencode/extensions/*/manifest.json")
       OpenCode Glob tool returns 0 results (hidden dir relative path bug)
  -> skill_name="" -> fallback to skill-implementer
  -> Skill("skill-implementer") loaded
  -> skill-implementer spawns Task("general-implementation-agent")
  -> General-Implementation-Agent runs Phase 1 of Lean proof task
     [lacks lean-lsp MCP tools, lean domain context, proof conventions]
```

### Key File Diffs

The fix applied in nvim's implement.md (not in ProofChecker) adds to STAGE 2:
- `project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)`
- `manifest_dir="$project_root/.opencode/extensions"`
- `manifest_count=0` counter with warning if count=0 after loops
- Replaces relative paths with `"$manifest_dir"/*/manifest.json`
- Removes hardcoded routing table (replaced by dynamic discovery)
- Adds delegation chain documentation
- Adds plan-file-as-primary-truth clarification

### Projects with Buggy Routing Commands

| Project | Path |
|---------|------|
| ProofChecker | `/home/benjamin/Projects/ProofChecker/.opencode/commands/` |
| dotfiles | `/home/benjamin/.dotfiles/.opencode/commands/` |
| OpenCode | `/home/benjamin/Projects/OpenCode/.opencode/commands/` |
| Zed | `/home/benjamin/.config/zed/.opencode/commands/` |
| ModelChecker | `/home/benjamin/Projects/ModelChecker/.opencode/commands/` |
| protocol | `/home/benjamin/Projects/protocol/.opencode/commands/` |

### Extension Timestamps

- Lean extension installed in ProofChecker: `2026-05-14T16:38:35Z`
- `/implement 129` session start: `2026-05-14T16:43:26Z` (5 min after install)
- Extension was fully installed before the failure occurred; only the routing discovery was broken
