# Research Report: Agent git-safety: preserve uncommitted work, guard destructive git ops

- **Task**: 780 - Agent git-safety: preserve uncommitted work, guard destructive git ops
- **Started**: 2026-07-03T00:00:00Z
- **Completed**: 2026-07-03T00:00:00Z
- **Effort**: 3-6 hours
- **Dependencies**: None (pairs with 779, 782; blocks 782, 785)
- **Sources/Inputs**:
  - `.claude/rules/git-workflow.md` and its extension-source mirror
  - `.claude/settings.json`, `.claude/extensions/core/root-files/settings.json`
  - `.claude/hooks/block-pr-submission.sh` (PreToolUse Bash-blocking precedent)
  - `.claude/hooks/validate-meta-write.sh`, `validate-plan-write.sh`, `validate-state-sync.sh` (PostToolUse validator precedents)
  - `.claude/hooks/subagent-postflight.sh` (marker-file + `decision:"block"` precedent)
  - `.claude/context/standards/git-safety.md` (existing sanctioned `git reset --hard` / `git clean -fd` rollback pattern)
  - `.claude/extensions/core/manifest.json` (`provides.hooks` wiring list)
  - git history: commits `1a3946b83`, `621d4bab0`, `ef50dcea4` (documents a real prior silent-hook-drop incident)
  - `specs/state.json` (task 780, 779, 782 descriptions)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The repo already has the **exact contract and blocking precedent** needed: `.claude/hooks/block-pr-submission.sh` is a `PreToolUse` hook matched on `"Bash"` that reads `tool_input.command` from stdin JSON and blocks via **exit code 2** (not `permissionDecision: deny`, which is documented as buggy when the tool is in the permissions `allow` list — issues #4669/#13214/#18312). The new `guard-destructive-git.sh` hook should copy this exact pattern.
- A **critical, previously-real failure mode** must be designed around: hooks and rules in this repo exist in **two copies** — a deployed copy (`.claude/hooks/`, `.claude/rules/git-workflow.md`) and a canonical extension-source copy (`.claude/extensions/core/hooks/`, `.claude/extensions/core/rules/git-workflow.md`, `.claude/extensions/core/root-files/settings.json`). A prior task (696) registered `block-pr-submission.sh` in `.claude/settings.json` only; the very next unrelated task (710) regenerated `settings.json` from `extensions/core/root-files/settings.json` (which was never updated) and **silently reverted the PR-blocking hook registration** — it is *still* unregistered in the current `.claude/settings.json` today. `block-pr-submission.sh` is also absent from `.claude/extensions/core/hooks/` and from `manifest.json`'s `provides.hooks` list. Task 780 must not repeat this: every new/changed file needs **both** copies updated, or it will be silently dropped by the next sync/regen.
- The existing `.claude/context/standards/git-safety.md` **already prescribes `git reset --hard {sha}` + `git clean -fd`** as the sanctioned command-level rollback pattern (e.g. for `/todo`) — but it always creates a safety commit on the *same* branch immediately beforehand. The new hook's "snapshot marker" logic must recognize this existing pattern as satisfying the "snapshot was just taken" exemption, or it will break `/todo` and similar commands.
- `.claude/hooks/subagent-postflight.sh` demonstrates the **marker-file pattern** already used in this codebase (`specs/{NNN}_{SLUG}/.postflight-pending`, gitignored) — this is the direct model for the snapshot marker the new hook checks.
- No dedicated hooks-contract documentation exists anywhere in `.claude/docs/` or `.claude/context/` — the JSON schema (`tool_input.command`, exit-code semantics, `additionalContext`/`permissionDecision` field differences between PreToolUse and PostToolUse) is currently tribal knowledge encoded only in hook script comments. This report documents it; the plan/implementation should consider adding a short reference doc.

## Context & Scope

Task 780 requires two layers plus a helper:

1. **Rule** (behavioral, advisory): extend `.claude/rules/git-workflow.md` with an explicit "no destructive git on uncommitted work" section.
2. **Hook** (enforced): a new `PreToolUse` hook script, `.claude/hooks/guard-destructive-git.sh` (also mirrored to `.claude/extensions/core/hooks/`), matched on the `Bash` tool, that inspects the command string for destructive git patterns and blocks (exit 2) unless the working tree is clean or a snapshot marker is fresh.
3. **Helper**: a small script agents call to snapshot recoverably before an intentional rollback (writes a `.patch` under `specs/{NNN}_{SLUG}/` and/or a WIP commit, and records the marker the hook checks).

This report covers the destructive-git pattern list, the exact hook input/output contract as evidenced by this repo's own hooks, the snapshot-marker design space, the helper script design, and the dual-copy wiring checklist required for the change to actually take effect and stay in effect.

## Findings

### Codebase Patterns

**PreToolUse Bash-blocking hook contract (`block-pr-submission.sh`)** — this is the direct model:
- Input: JSON on **stdin** (not just the `CLAUDE_TOOL_INPUT` env var used by some older `PreToolUse`/`PostToolUse` matchers in `settings.json`). Read via `INPUT=$(cat)`.
- Command extraction: `echo "$INPUT" | jq -r '.tool_input.command // empty'`.
- Non-Bash / parse-failure guard: if `COMMAND` is empty, `exit 0` (allow through) — critical so the hook never blocks non-Bash tool calls or malformed input.
- Pattern matching: `grep -qE` against the command string, anchored with `(^|[;&|] *)` so mid-string mentions inside quotes/comments are not false-matched.
- **Blocking mechanism: `exit 2`, with the corrective message on `stderr`.** The script's own header comment explains why: `permissionDecision: "deny"` in the JSON stdout is documented as buggy when the tool/pattern is already in the `permissions.allow` list (which `Bash(git:*)` is, per `.claude/settings.json`) — GitHub issues #4669, #13214, #18312. Exit code 2 is the reliable blocking mechanism regardless of allow-list state; stderr text becomes the corrective context shown back to the agent.
- Non-blocking exit: `exit 0` at the end for the allow-through path.

**PostToolUse advisory/validation contract** (`validate-plan-write.sh`, `validate-meta-write.sh`, `validate-state-sync.sh`):
- Input: read from stdin first (`INPUT=$(cat)`, `.tool_input.file_path`), falling back to `$CLAUDE_TOOL_INPUT` env var for compatibility.
- Output is **JSON on stdout**, not exit code: `{}` for no feedback, `{"additionalContext": "..."}` to inject advisory text back to the agent without blocking (PostToolUse cannot block — the tool already ran). `validate-plan-write.sh` layers exit codes from its inner validator (0=valid, 1=validation failed, 2=auto-fixed) purely to select which `additionalContext` message to emit — the hook itself still `exit 0`s in every branch.
- This confirms **PreToolUse and PostToolUse use different blocking mechanisms**: PreToolUse can genuinely block via exit code 2 (or, unreliably per the allow-list bug, `permissionDecision`); PostToolUse can only annotate after the fact, since the tool call already completed.

**Marker-file pattern** (`subagent-postflight.sh`):
- Uses a **task-scoped marker file** discovered via `find specs -maxdepth 3 -name ".postflight-pending"`, falling back to a global marker for compatibility.
- Companion loop-guard file in the same directory prevents infinite re-trigger.
- `.postflight-pending` is gitignored (`**/.postflight-pending` in `.gitignore`) — the marker is ephemeral local coordination state, not a committed artifact. This is the direct precedent for a `.git-snapshot-marker` (or similarly named) file the destructive-git hook checks and the snapshot helper writes.
- `SubagentStop` hooks return `{"decision": "block", "reason": "..."}` to prevent stop — a third response-field vocabulary (`decision`/`reason`), distinct from `permissionDecision`/`permissionDecisionReason` (PreToolUse) and `additionalContext` (PostToolUse). This confirms the field names are event-type-specific, not universal.

**`hooks.PreToolUse` registration shape in `settings.json`**:
```json
"PreToolUse": [
  {
    "matcher": "Bash",
    "hooks": [
      { "type": "command", "command": "bash .claude/hooks/guard-destructive-git.sh 2>/dev/null || echo '{}'" }
    ]
  }
]
```
This exact shape (matcher `"Bash"`, single command hook) previously existed for `block-pr-submission.sh` at commit `1a3946b83`/`621d4bab0` — see Risk below, it no longer exists in the live file.

**Existing sanctioned destructive-git usage** (`.claude/context/standards/git-safety.md`, referenced from `index.json` at `standards/git-safety.md`): this doc prescribes `git reset --hard {safety_commit_sha}` and `git clean -fd` as the canonical rollback pattern for commands like `/todo`, but *always* immediately preceded by `git add {files}; git commit -m "safety: pre-{operation} snapshot"` on the same branch. This is functionally identical to the "WIP commit" snapshot option task 780 already allows — the hook's freshness check (e.g. "HEAD commit created within last N seconds" or an explicit marker written by the commit step) must recognize this pattern so `/todo` and other git-safety.md-following commands are not broken by the new hook.

**Destructive-git rule gap in `git-workflow.md`**: the current "Git Safety" section only has a blanket `Never Run: git reset --hard without explicit user request` (an absolute prohibition, no clean-tree exemption or snapshot-first alternative) and does not mention `git checkout -- <path>`, `git restore`, `git clean -fd`, or `git stash drop/clear` at all. This needs to be replaced/extended with the nuanced "blocked unless clean or just-snapshotted" rule from the task description.

### Destructive-Git Pattern List (from task description, cross-checked against git-safety.md's sanctioned usage)

| Pattern | Regex anchor style (model: `block-pr-submission.sh`) | Note |
|---|---|---|
| `git reset --hard` | `(^\|[;&\|] *)git reset (\S+ )*--hard` | Also matches `git reset --hard HEAD~1`, `git reset --hard <sha>` |
| `git checkout -- <path>` | `(^\|[;&\|] *)git checkout .*--\s` or `git checkout -- ` | Discards worktree changes to specific paths |
| `git checkout <branch>` / `git switch <branch>` (dirty tree) | matched generically; git itself blocks on dirty tree unless `-f`/`--force` is present — the hook should specifically flag `-f`/`--force` variants, and treat force-less checkout/switch as already git-guarded (defense in depth only) | |
| `git restore <path>` (no `--staged`) | `(^\|[;&\|] *)git restore (?!--staged)` | `git restore --staged` only unstages, does not touch worktree — must be exempted |
| `git clean -fd` (and `-df`, `-fdx`, `-xdf`, etc.) | `(^\|[;&\|] *)git clean .*-[a-z]*f[a-z]*d` (flag-order-agnostic) | Deletes untracked files/dirs irreversibly |
| `git stash drop` / `git stash clear` | `(^\|[;&\|] *)git stash (drop\|clear)` | Destroys stash entries; `git stash` (push) and `git stash pop`/`apply` are NOT destructive and must not be flagged |

Exemption logic (per task description): block **unless** (a) `git status --porcelain` is empty (clean tree — nothing to lose), or (b) a snapshot marker shows a snapshot was *just* created (freshness-bounded, e.g. last N seconds/minutes, or single-use "consume on check" marker).

### Hook Input/Output Contract (consolidated)

**PreToolUse** (what the new hook must implement):
- Reads full JSON from stdin: `{"tool_name": "Bash", "tool_input": {"command": "...", ...}, "session_id": "...", "cwd": "...", "hook_event_name": "PreToolUse", ...}` (fields beyond `tool_input.command` observed via the settings.json registration pattern and Claude Code's general hook payload shape; this repo's own hooks only ever consume `tool_input.command` or `tool_input.file_path`).
- To **block**: print a corrective message to **stderr** and `exit 2`. Do NOT rely on `{"permissionDecision": "deny"}` on stdout — documented-buggy for allow-listed tools in this repo (`Bash(git:*)` is allow-listed).
- To **allow**: `exit 0` (stdout content is ignored/optional on the allow path; existing hooks emit nothing or `{}`).
- Must guard empty/non-Bash input with an early `exit 0` so parse failures never accidentally block.
- Registration: `"matcher": "Bash"` (whole-tool matcher; the script itself does the fine-grained command pattern matching — there is no per-command-pattern matcher syntax in this codebase's hook usage).

**PostToolUse** (not used for blocking, but relevant if an advisory companion is wanted, e.g. to nudge a `/todo`-style safety commit after a snapshot helper runs):
- Reads `tool_input.file_path` (Write/Edit) via stdin, falls back to `$CLAUDE_TOOL_INPUT`.
- Cannot block; returns `{"additionalContext": "..."}` JSON on stdout, always `exit 0`.

### Snapshot-Marker Mechanism (design findings)

- Model directly on `subagent-postflight.sh`'s `.postflight-pending` marker: a small file, gitignored, discovered via `find specs -maxdepth 3 -name "<marker-name>"` (task-scoped) with a global fallback.
- Needs **freshness**, not just presence — an old stale marker from a prior session must not silently authorize a new, unrelated destructive command. Options: (a) marker content includes a timestamp and the hook checks it's within a short window (e.g. 120s) of "now"; (b) marker is consumed/deleted by the hook on first successful check (single-use); (c) marker content includes the current `git status --porcelain` hash or `HEAD` sha it was taken against, and the hook verifies nothing changed since. Given the task's directive to "keep it lightweight," a timestamp-window check (a) combined with delete-on-use (b) is the simplest robust combination and matches the lightweight-marker precedent already in the codebase.
- Must be **git-ignored** (add pattern to `.gitignore`, mirroring `**/.postflight-pending`) since it is ephemeral coordination state, not a task artifact.
- The **`.patch` artifact**, by contrast, is an intentional recoverable artifact and belongs under `specs/{NNN}_{SLUG}/` (task description's own example: `working-progress-{ts}.patch`) — this should be committed/tracked, not gitignored, since it is the actual recovery payload if a rollback goes wrong. This creates two distinct file classes to keep straight in the implementation: (1) the ephemeral marker (gitignored, drives the hook's exemption check) and (2) the durable patch/commit (the actual recoverable snapshot).
- The task also allows a **WIP commit on a scratch branch** or **plain `git stash`** (without drop) as alternative snapshot forms — all three should presumably set/refresh the same marker so the hook's exemption logic is agnostic to which snapshot method was used.

### Helper Script Design

A small script (e.g. `.claude/scripts/git-snapshot.sh`, called by agents before an intentional rollback) should:
1. Determine if the tree is dirty (`git status --porcelain`); no-op with a clear message if already clean (nothing to snapshot).
2. Default mode: write a `.patch` via `git diff HEAD > specs/{NNN}_{SLUG}/working-progress-{ts}.patch` (task number/slug likely passed as an arg or inferred from the active task dir) **and** `git stash` (without drop) as a belt-and-suspenders in-repo copy, OR support a `--branch` flag for a WIP commit on a scratch branch (`git checkout -b wip-snapshot-{ts}`, commit, return to original branch) as an alternative mode.
3. Write/refresh the snapshot marker (timestamp + optionally the `HEAD` sha / patch path) that `guard-destructive-git.sh` checks.
4. Print the patch path / stash ref / branch name so the calling agent can reference it if recovery is needed later.
5. Exit non-zero with a clear message on any failure (e.g. `git diff` or `git stash` failing) so the caller does not proceed to the destructive step believing it is safe.

### External Resources

No external (web) research was needed — this is a self-contained agent-system (meta) task whose entire contract is defined by this repository's own prior hook implementations and Claude Code's general PreToolUse/PostToolUse hook mechanism (stdin JSON in, exit-code/stdout-JSON out), which is already faithfully reverse-engineered from working code in this repo (see `block-pr-submission.sh` comments referencing GitHub issues #4669/#13214/#18312 for the `permissionDecision` deny-with-allow-list bug).

## Decisions

- Model `guard-destructive-git.sh` directly on `block-pr-submission.sh`: stdin JSON, `tool_input.command`, anchored `grep -qE` patterns, block via **`exit 2` + stderr message** (not `permissionDecision: deny`), early `exit 0` on empty/non-Bash input.
- Model the snapshot marker directly on `subagent-postflight.sh`'s `.postflight-pending`: task-scoped file under `specs/{NNN}_{SLUG}/`, gitignored, with a global fallback; add freshness (timestamp window) and delete-on-use semantics.
- Treat `.claude/context/standards/git-safety.md`'s existing safety-commit-then-`reset --hard`/`clean -fd` pattern as an implicit, already-fresh "snapshot" (a commit at `HEAD` immediately prior) — the hook's clean-or-fresh-marker check must not break this existing sanctioned command flow.
- The rule addition to `git-workflow.md` must be written into **both** `.claude/rules/git-workflow.md` and `.claude/extensions/core/rules/git-workflow.md` (currently byte-identical) to avoid the copy silently reverting on next sync.
- The hook script must be created in **both** `.claude/hooks/guard-destructive-git.sh` (deployed) and `.claude/extensions/core/hooks/guard-destructive-git.sh` (canonical source), and added to `.claude/extensions/core/manifest.json`'s `provides.hooks` array — `block-pr-submission.sh` was never added to either, which is a plausible contributing factor to why its `settings.json` registration was so easily lost and never restored.
- The `settings.json` registration must be added to **both** the live `.claude/settings.json` and `.claude/extensions/core/root-files/settings.json` (the sync source used by the picker's "Load Core" operation and the extension loader, per `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`) — this is the exact mechanism that silently dropped `block-pr-submission.sh`'s registration in commit `ef50dcea4` (task 710) and it remains unregistered in current `HEAD`.

## Risks & Mitigations

- **Risk**: Repeating the exact `block-pr-submission.sh` wiring failure — new hook registered in only one of the two settings.json copies, silently dropped on next unrelated sync/regen commit. **Mitigation**: explicit wiring checklist in the plan covering both settings.json copies, both hook-script copies, the manifest's `provides.hooks` list, and both rule-file copies; verify with `diff` after implementation, as done in this report.
- **Risk**: Overly broad pattern matching false-blocks legitimate clean-tree operations (e.g. `git checkout main` on a clean tree, `git clean -fd` in an already-clean repo) or benign strings containing these substrings inside commit messages/quoted args. **Mitigation**: reuse `block-pr-submission.sh`'s anchored-pattern style (`(^|[;&|] *)`) and gate all matches behind the `git status --porcelain` clean-tree check first (cheap, always run first) before even evaluating command patterns — if clean, always `exit 0` immediately.
- **Risk**: Breaking existing sanctioned rollback flows that use `git reset --hard`/`git clean -fd` right after a safety commit (`.claude/context/standards/git-safety.md`, used by `/todo` and similar). **Mitigation**: the freshness window on the snapshot marker (or a "HEAD changed since last check" style detection) should recognize a commit made in the same tool-call sequence as satisfying the exemption; test against the `/todo` archival flow specifically during implementation/plan verification.
- **Risk**: Marker staleness — an agent snapshots once, then runs multiple unrelated destructive commands much later, all silently exempted by one old marker. **Mitigation**: short freshness window + delete-on-use (single-shot marker), as noted in Findings.
- **Risk**: No existing hooks-contract reference doc means future hook authors will re-derive the same `permissionDecision`-bug knowledge from scratch by reading `block-pr-submission.sh` comments. **Mitigation** (optional, not required for task 780's scope but worth flagging): consider a short `.claude/docs/reference/hooks-contract.md` capturing this report's "Hook Input/Output Contract" section for reuse; left as a Context Extension Recommendation below rather than in-scope for this task.

## Context Extension Recommendations

- **Topic**: PreToolUse/PostToolUse/SubagentStop hook JSON contract (stdin schema, blocking mechanism per event type, the `permissionDecision`-deny-with-allow-list bug)
- **Gap**: This knowledge currently exists only as comments scattered across individual hook scripts (`block-pr-submission.sh`, `validate-plan-write.sh`, `subagent-postflight.sh`); there is no consolidated reference in `.claude/docs/` or `.claude/context/`.
- **Recommendation**: After task 780 lands `guard-destructive-git.sh` as a second real-world PreToolUse-blocking example, consider creating `.claude/docs/reference/hooks-contract.md` (or similar) consolidating the input schema and per-event-type response contract, referencing both `block-pr-submission.sh` and `guard-destructive-git.sh` as worked examples. Not required for task 780 itself.
- **Topic**: `block-pr-submission.sh`'s own broken wiring (unregistered in current `settings.json`, absent from `extensions/core/hooks/` and `manifest.json`)
- **Gap**: The PR-blocking hook that task 696 fixed was silently reverted by task 710's unrelated settings.json regen and has never been restored; it is not part of task 780's stated scope but is directly adjacent (same file, same wiring mechanism) and currently non-functional in production.
- **Recommendation**: Flag for a follow-up task (or fold into 780's implementation as a fast drive-by fix, if the plan/implementer judges it in-scope) to re-register `block-pr-submission.sh` in `.claude/settings.json` PreToolUse + `.claude/extensions/core/root-files/settings.json`, and add the script to `.claude/extensions/core/hooks/` + `manifest.json`'s `provides.hooks`.

## Appendix

- Search queries / commands used: `git log --oneline --all -- .claude/hooks/block-pr-submission.sh`, `git show <sha>:.claude/settings.json`, `git diff 621d4bab0 ef50dcea4 -- .claude/settings.json`, `grep -rn "root-files" lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`.
- Key files read in full: `.claude/rules/git-workflow.md`, `.claude/hooks/block-pr-submission.sh`, `.claude/hooks/validate-meta-write.sh`, `.claude/hooks/validate-plan-write.sh`, `.claude/hooks/validate-state-sync.sh`, `.claude/hooks/subagent-postflight.sh` (partial), `.claude/context/standards/git-safety.md`, `.claude/settings.json`, `.claude/extensions/core/root-files/settings.json`.
- Related tasks (not yet started, referenced for context): task 779 (fix-forward recovery contract, depends on 780), task 782 (targeted commit staging, depends on 780 — serialized because it also edits `git-workflow.md`).
