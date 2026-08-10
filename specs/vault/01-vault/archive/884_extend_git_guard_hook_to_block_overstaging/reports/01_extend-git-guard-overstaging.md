# Research Report: Task #884

**Task**: 884 - extend_git_guard_hook_to_block_overstaging
**Started**: 2026-07-15
**Completed**: 2026-07-15
**Effort**: Small-medium (single-file hook extension + regex design + 2 prose edits)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `.claude/hooks/guard-destructive-git.sh` (== `agent-system/extensions/core/hooks/guard-destructive-git.sh`), `.claude/settings.json`, `.claude/scripts/git-snapshot.sh`, `.claude/context/standards/git-staging-scope.md`, `.claude/rules/git-workflow.md`, `.claude/skills/skill-git-workflow/SKILL.md`, `.claude/skills/skill-project-overview/SKILL.md`, `.claude/context/orchestration/postflight-pattern.md`, `.claude/docs/architecture/handoff-schema.md`
**Artifacts**:
- This report: `specs/884_extend_git_guard_hook_to_block_overstaging/reports/01_extend-git-guard-overstaging.md`
- Orchestrator handoff: `specs/884_extend_git_guard_hook_to_block_overstaging/.orchestrator-handoff.json`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The hard part resolves cleanly, with no exemption logic required.** `guard-destructive-git.sh` is a PreToolUse **Bash** hook: it inspects only the literal `tool_input.command` string of the Bash tool call the agent issues. `git-snapshot.sh`'s sanctioned `git add -A` (line 150, `--branch` mode) runs as a subprocess *inside* the script, invoked by agents exclusively as the opaque top-level call `bash .claude/scripts/git-snapshot.sh [--branch] [TASK]`. That literal string never contains the substrings `git add -A`/`--all` or `git add .` — the hook structurally cannot see the internal command, so no marker, allowlist, or caller-identification mechanism is needed to exempt it. This is a different situation from the *existing* destructive-command guard's marker exemption, which exists to authorize an agent's own **subsequent, literal** `git reset --hard`/etc. call after taking a snapshot — not to hide `git-snapshot.sh`'s internals (which were already invisible).
- **Source-of-truth is `agent-system/extensions/core/`, not `.claude/`.** `.claude/` is fully gitignored (`.gitignore:7` — `/.claude/`) as of a prior "untrack the .claude/ deploy tree" commit. All six target files (the hook, `git-snapshot.sh`, `git-staging-scope.md`, `git-workflow.md`, `skill-git-workflow/SKILL.md`, `skill-project-overview/SKILL.md`, `postflight-pattern.md`) exist in both trees today and are byte-identical. Implementation must edit the `agent-system/extensions/core/...` copies (the deployed `.claude/...` copies are sync targets and will diverge/be overwritten otherwise).
- **Recommended regex additions** (same style as the existing patterns in the hook — segment-split on `;`/`&`/`|`, `grep -qE` per segment): detect `git add` segments containing a `-A`/`--all` flag or a bare `.` pathspec token; detect `git commit` segments containing a `-a`/`--all` flag (with or without `-m`). Care is needed to anchor short-flag detection so `--amend`/`--author=...` are not false-matched (verified safe using the same leading-boundary-assertion technique the existing `clean -f -d` detector already uses).
- **Prose reconciliation has one clean case and one nuance.** `postflight-pattern.md:228,247` ("Manual fix: `git add . && git commit`") directly teaches a command the extended hook will now block — must be fixed. `skill-project-overview/SKILL.md:435` (`git add specs/ .claude/`) is **not** literally one of the three blocked forms (no `-A`, no bare `.`, no `-am`) — it is a policy inconsistency with `git-staging-scope.md`'s narrower per-operation contract, not something the hook will technically reject. The report flags this distinction so the plan doesn't overclaim hook coverage for that line; it should still be reconciled to match the canonical narrow scope for consistency, but the justification is "the policy already forbids this pattern of over-broad staging" rather than "the hook will block it."

## Context & Scope

Task 884 asks to extend the existing `guard-destructive-git.sh` PreToolUse hook (rather than adding a second git-guarding hook) to block `git add -A`, `git add .`, and `git commit -am` at the tool boundary, while preserving the one sanctioned `git add -A` inside `git-snapshot.sh --branch` mode, and to reconcile two prose locations that currently instruct agents to run commands the new guard would block.

## Findings

### Existing Hook Mechanics

`.claude/hooks/guard-destructive-git.sh` (registered in `.claude/settings.json:90-107` as a `PreToolUse` hook with `"matcher": "Bash"`, `"command": "bash .claude/hooks/guard-destructive-git.sh"`):

1. Reads the Bash tool call's JSON on stdin, extracts `tool_input.command` via `jq`.
2. Exits 0 (allow) immediately if `COMMAND` is empty (non-Bash tool / parse failure).
3. Exits 0 immediately if `git status --porcelain` is empty (clean tree — nothing to lose). This is the guard's primary safety valve and also the mechanism that exempts `/todo`'s post-safety-commit rollback flow.
4. Runs a sequence of `MATCHED=0`/pattern-check blocks, each scanning `COMMAND` (or, for multi-flag operations like `clean`, each `;`/`&`/`|`-delimited segment of `COMMAND`) for one destructive shape: `reset --hard`, `checkout -- <path>`, `restore <path>` (non-`--staged`), `clean -f -d` (any clustering), `stash drop/clear`, forced `checkout`/`switch`.
5. If nothing matched, exits 0.
6. If something matched, checks for a fresh (≤120s) unconsumed `.git-snapshot-marker` under `specs/**` (written by `git-snapshot.sh`); if found and fresh, deletes it (single-use) and exits 0.
7. Otherwise: prints `BLOCKED: <reason>` plus remediation guidance to stderr, exits 2 (blocks the tool call).

The `clean -f -d` detector (lines 78-94) is the closest existing precedent for a "flag combination, any order/clustering" check, and the `restore`/forced-`checkout`/`switch` detectors (lines 62-115) are the precedent for "iterate per matched segment, inspect for a specific flag." The new `git add`/`git commit` detectors should follow this exact idiom — same segment-splitting regex (`(^|[;&|][[:space:]]*)git[[:space:]]+<verb>[^;&|]*`), same `while IFS= read -r seg; do ... done <<< "$SEGMENTS"` loop shape, same `MATCHED=1; REASON="..."; break` pattern.

### Settings.json Registration

No changes needed here — the task explicitly constrains work to extending the existing script; the `PreToolUse`/`Bash`/`guard-destructive-git.sh` registration in `.claude/settings.json:90-107` (mirrored in `agent-system/extensions/core/settings.json` if present — not checked, but the hook *script* itself is confirmed to live in and sync from `agent-system/extensions/core/hooks/`) stays untouched.

### Source-of-Truth Architecture (must-know for implementation)

`.claude/` is entirely gitignored:
```
.gitignore:7:/.claude/	.claude/hooks/guard-destructive-git.sh
```
(the inline comment on that gitignore line even names this exact hook file). A prior commit (`6c06987af chore: gitignore and untrack the .claude/ deploy tree`) removed `.claude/` from version control; `agent-system/extensions/core/` is now the tracked source tree, deployed/synced into `.claude/` by an install/sync mechanism (`.claude/scripts/install-extension.sh`, `.syncprotect`, `.sync-exclude` govern this — not fully traced, out of scope for this report). Confirmed byte-identical today for every file this task touches:

| File | `agent-system/extensions/core/...` | `.claude/...` | Status |
|---|---|---|---|
| hook script | `hooks/guard-destructive-git.sh` | `hooks/guard-destructive-git.sh` | identical |
| snapshot script | `scripts/git-snapshot.sh` | `scripts/git-snapshot.sh` | identical |
| staging policy | `context/standards/git-staging-scope.md` | same | identical |
| workflow rule | `rules/git-workflow.md` | same | identical |
| git-workflow skill | `skills/skill-git-workflow/SKILL.md` | same | identical |
| project-overview skill | `skills/skill-project-overview/SKILL.md` | same | identical |
| postflight pattern | `context/orchestration/postflight-pattern.md` | same | identical |

**Implication for planning**: every edit in this task's scope must be made under `agent-system/extensions/core/...`. None of the six target files appear in `.syncprotect` (which only lists `context/repo/project-overview.md` and `output/implementation-001.md`), so a normal sync will safely propagate edits from the source tree into `.claude/`.

### The Hard Part: git-snapshot.sh Exemption — Resolved, No New Mechanism Needed

The task frames this as the genuinely hard design question. Tracing it concretely:

- `git-snapshot.sh:150` runs `git add -A` (and the following `git commit -m "wip snapshot ${TS}"`) **only** inside `MODE="branch"` (`--branch` flag), after `git checkout -b "$BRANCH_NAME"` onto a throwaway `wip-snapshot-${TS}` branch, and before returning to the original branch. Confirmed this is the only `git add -A` in any executable script under `.claude/`/`agent-system/extensions/core/` (`grep -rn "git add -A" ... --include="*.sh"` — single hit).
- Every documented invocation site of this script — `.claude/rules/git-workflow.md`, `.claude/context/contracts/recovery.md`, `.claude/context/patterns/checkpoint-before-overflow.md`, `.claude/agents/general-implementation-agent.md`, `general-implementation-hard-agent.md`, `general-research-agent.md`, `general-research-hard-agent.md`, `.claude/skills/skill-orchestrate-hard/SKILL.md` — instructs agents to call it as a single opaque command: `bash .claude/scripts/git-snapshot.sh [--branch] [TASK]`. No documented or discovered call site inlines the script's internal `git add -A`/`git commit` as a literal, separate Bash tool invocation.
- `guard-destructive-git.sh` (and, by extension, its planned successor) only ever sees `tool_input.command` — the literal text of the Bash tool call the agent issued. When an agent runs `bash .claude/scripts/git-snapshot.sh --branch 884`, the hook's `COMMAND` variable is exactly that string. It does not contain `add`, `-A`, or `commit` as substrings, so **no pattern match, marker, or allowlist entry is required** for the extended hook to leave this call alone — it structurally never reaches the new detection blocks in the first place (the literal string doesn't even parse as a `git` command at all, let alone `git add`/`git commit`).
- Contrast with the *existing* destructive-command guard's marker mechanism: that mechanism exists because after calling `git-snapshot.sh`, the agent then issues its own **separate, literal** Bash call such as `git reset --hard {sha}` — *that* call's literal text does match the destructive patterns, so a marker is needed to authorize it for the ~120s following a fresh snapshot. There is no equivalent downstream literal call for the staging guard: nothing in the sanctioned flow requires an agent to *itself* type `git add -A`, `git add .`, or `git commit -am` after running `git-snapshot.sh`. `git-snapshot.sh --branch` mode is fully self-contained (branch, add, commit, return-to-original-branch all happen inside the one script invocation).
- **Conclusion for the plan**: implement the three new detectors as straightforward, unconditional blocks (matching the existing style — segment scan, `MATCHED=1`, `exit 2` with a `BLOCKED:` message) with **no interaction with the existing marker/freshness-window mechanism at all**. Do not attempt to special-case `git-snapshot.sh`'s internal command by inspecting environment variables, caller identity, or a "trusted script" allowlist — none of that machinery is reachable or necessary, since the hook never observes the internal command text. This should be stated explicitly and prominently in the implementation plan and in a comment in the hook itself (mirroring the existing header comment style at lines 1-27), so a future maintainer does not spend effort trying to add exemption logic that solves a problem which does not exist at this hook's observation boundary.
- **One residual risk worth flagging** (not a code change, a documentation/behavioral note): if a future agent or human ever "helpfully" reproduces `git-snapshot.sh --branch`'s logic inline as literal Bash tool calls (`git checkout -b wip-snapshot-... && git add -A && git commit ...`) instead of calling the script, the new guard **will** correctly block the inlined `git add -A`. This is desired behavior — it reinforces "always call the sanctioned script" — but the plan/summary should note it so it isn't mistaken for a bug during verification.

### Regex Design for the Three New Detectors

Following the existing hook's idiom exactly (segment-split on `(^|[;&|][[:space:]]*)git[[:space:]]+<verb>[^;&|]*`, then a `while read` loop over segments):

**1. `git add -A` / `git add --all`**
- Detect a `-A` short flag or `--all` long flag within a `git add ...` segment.
- Use the same leading-boundary-assertion approach as the existing `clean -f/-d` detector to avoid mid-token false positives, e.g. `(^|[[:space:]])-[a-zA-Z]*A[a-zA-Z]*([[:space:]]|$)` for the short form, `--all\b` for the long form (verified: `--all\b` does not false-match `--allow-empty` because `\b` requires a non-word char after `l`, and `-l` followed by `o` is not a boundary).

**2. `git add .` (bare current-directory pathspec)**
- Must match only a standalone `.` token, not `.gitignore`, `.env`, `./subdir/file.lua`, etc. Pattern: a `.` token bounded by whitespace/segment edges, e.g. `(^|[[:space:]])\.([[:space:]]|$)` scoped to the `git add` segment only (never applied to `git commit` or other verbs).

**3. `git commit -a` / `-am` / `--all`**
- The task names `git commit -am` specifically, but the underlying hazard is `-a`/`--all` regardless of `-m` presence (`git commit -a` alone also implicitly stages all tracked modifications — it just opens an editor instead of taking `-m`). Recommend detecting `-a`/`--all` presence in a `git commit ...` segment unconditionally (matches the parenthetical in `git-staging-scope.md:112` and `skill-git-workflow/SKILL.md:142`, which both describe the hazard as "-am (implicitly stages all tracked-file modifications)" without gating on `-m`'s presence).
- Verified via manual regex trace (segment-anchored `(^|[[:space:]])-[a-zA-Z]*a[a-zA-Z]*([[:space:]]|$)` plus a separate `--all\b` check) that this does **not** false-match `--amend` or `--author=...`: both are double-dash long options, and the required `(^|[[:space:]])` boundary immediately before the matched `-` cannot align with the *second* dash of a `--` option (the character immediately before the second dash is the first dash, which is neither whitespace nor start-of-string), so the short-flag branch of the regex cannot latch onto a long option's tail. This mirrors how the existing hook safely disambiguates `-f`/`-d` clustering from unrelated flags today.
- `git commit -a -m "..."` (split flags) is still caught because the detector scans the whole segment for a matching flag token, not just the first token after `commit`.

**Suggested `REASON` strings** (for the `BLOCKED:` message, consistent with the existing hook's phrasing style):
- add: `"git add -A (or --all) stages the entire working tree; use targeted staging per git-staging-scope.md instead"`
- add `.`: `"git add . stages the entire current directory tree; use targeted staging per git-staging-scope.md instead"`
- commit: `"git commit -a/-am (or --all) implicitly stages all tracked-file modifications; stage explicit paths and commit without -a instead"`

These three new blocks do **not** need the clean-tree short-circuit (step 3 above) to be bypassed or altered — over-staging on an already-clean tree is a no-op anyway (nothing to over-stage), so it is safe and consistent for the new detectors to run through the same "clean tree exits 0 early" gate as the rest of the hook. No change needed to that gate.

### Prose Contradictions

**1. `agent-system/extensions/core/context/orchestration/postflight-pattern.md:228` and `:247`** (both inside `skill-git-workflow`'s validate-return fallback guidance):
```
echo "Manual fix: git add . && git commit -m 'task $task_number: ${command} completed'"
```
This is a direct, literal instruction to run a command the extended hook will now block on a dirty tree. **Recommend**: replace with guidance pointing at the scoped-staging template already documented in `git-staging-scope.md` (task directory + `specs/TODO.md` + `specs/state.json`, plus plan/modified-files for `implement`), e.g. `"Manual fix: stage the task-scoped files per git-staging-scope.md and commit manually (do not use git add -A/./-am)"`. Both occurrences (lines 228 and 247, in the two parallel `jq`-parse-failure and `status == "failed"` branches) need the same fix.

**2. `agent-system/extensions/core/skills/skill-project-overview/SKILL.md:435`**:
```
git add specs/ .claude/
git commit -m "task ${next_num}: create and complete research
...
```
This does **not** match any of the three new detector patterns (no `-A`, no bare `.` token, no `-a`/`-am`/`--all`) — it is a directory-list `git add` with two explicit paths, which is syntactically a form of scoped staging, just far too wide a scope (staging *all* of `specs/` and *all* of `.claude/`, rather than the single task directory plus the two index files per `git-staging-scope.md`). It will **not** be blocked by the new hook. It is flagged in the task description as "the widest non-`-A` prescription in the system" — a genuine policy inconsistency worth fixing for consistency with the canonical narrow per-operation scope, but the plan should not describe this fix as "required so the hook doesn't block it," since technically it wouldn't be blocked. **Recommend**: narrow to the canonical template from `git-staging-scope.md`'s "Reference Template" section, e.g.:
```
padded_num=$(printf "%03d" "$next_num")
git add "specs/${padded_num}_${slug}/" specs/TODO.md specs/state.json
```
(exact variable names should match whatever the surrounding SKILL.md step already uses for `next_num`/slug).

## Decisions

- Extend `guard-destructive-git.sh` in place; no new hook file, no `settings.json` change.
- No exemption/marker/allowlist logic is needed for the `git-snapshot.sh --branch` internal `git add -A` — it is structurally invisible to the hook. Do not build one.
- The `git commit` detector should catch bare `-a`/`--all` (not just literal `-am`), since the underlying hazard (implicit staging of all tracked modifications) is identical with or without `-m`.
- Both target files for the six-file source-of-truth set are edited under `agent-system/extensions/core/...`, never `.claude/...` directly.

## Risks & Mitigations

- **Risk**: a future contributor adds a new legitimate script that must run `git add -A`/`git commit -am` as a literal top-level Bash tool call (not wrapped in a script like `git-snapshot.sh`). **Mitigation**: none needed today (no such case exists — verified via full-repo grep), but the hook's header comment should say explicitly that the guard has no exemption mechanism for over-staging commands and any future legitimate need must be wrapped in a script (as `git-snapshot.sh` already is) rather than special-cased in the hook.
- **Risk**: regex false positives on `--amend`, `--author=`, `.gitignore`/`.env` pathspecs. **Mitigation**: verified via manual trace (see Regex Design section) that the segment-anchored, boundary-asserted patterns used elsewhere in this hook do not false-match these; implementation should add these exact cases to whatever manual/scripted verification is used (there is no existing automated test harness for this hook — see Appendix).
- **Risk**: `.claude/` vs `agent-system/extensions/core/` divergence if edits land in the wrong tree. **Mitigation**: explicitly called out above; implementer should verify `diff -q` between the two trees for all six touched files before considering the task done (or run whatever sync script exists, if the plan surfaces one).

## Context Extension Recommendations

- **Topic**: no automated test harness exists for `guard-destructive-git.sh` (a prior task, `769_routing_hard_consistency_guard`, has an archived `test-guard.sh` but it is unrelated to this hook). **Gap**: hook regex changes are currently verified only by manual trace/inspection, which is exactly the kind of thing that regresses silently. **Recommendation**: consider a lightweight `.claude/hooks/tests/test-guard-destructive-git.sh` (or similar) that pipes representative `tool_input.command` JSON payloads through the hook and asserts exit codes, covering both the existing destructive-command cases and (after this task) the new over-staging cases plus the `--amend`/`.env`/`.gitignore` false-positive-avoidance cases identified above. Out of scope for this task's implementation but worth a follow-up task.

## Appendix

### Search Queries / Commands Used
- `grep -rn "git add -A\|git add \.\b\|git commit -am" .claude --include="*.sh" --include="*.md" --include="*.json"`
- `grep -rln "git-snapshot.sh" .claude --include="*.sh" --include="*.md"` and per-file `grep -n -B2 -A2` on each hit
- `diff -q` across all six `agent-system/extensions/core/...` vs `.claude/...` file pairs
- `git check-ignore -v .claude/hooks/guard-destructive-git.sh`
- `git log --oneline -3 -- <path>` on both tree copies of the hook to establish which is the tracked source

### Key File Locations
- Hook (source of truth): `agent-system/extensions/core/hooks/guard-destructive-git.sh`
- Hook (deployed, gitignored): `.claude/hooks/guard-destructive-git.sh`
- Registration: `.claude/settings.json:90-107` (and presumably a mirrored `agent-system/extensions/core/settings.json`, not verified in this pass)
- Sanctioned exemption case: `agent-system/extensions/core/scripts/git-snapshot.sh:150` (`--branch` mode only)
- Canonical staging policy: `agent-system/extensions/core/context/standards/git-staging-scope.md`
- Prose fix #1: `agent-system/extensions/core/context/orchestration/postflight-pattern.md:228,247`
- Prose fix #2: `agent-system/extensions/core/skills/skill-project-overview/SKILL.md:435`
