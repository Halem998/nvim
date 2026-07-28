# Research Report: Task #941

**Task**: 941 - Purge ephemeral task-management references from deliverables and enforce the rule going forward
**Started**: 2026-07-28T17:00:00Z
**Completed**: 2026-07-28T17:08:00Z
**Effort**: large (research only; implementation is multi-phase, see Recommendations)
**Dependencies**: None
**Sources/Inputs**:
  - Codebase: `agent-system/extensions/core/hooks/validate-no-task-references.sh`, `agent-system/extensions/core/scripts/check-extension-docs.sh`, `agent-system/extensions/core/scripts/verify-deploy.sh`, `agent-system/extensions/core/manifest.json`, `agent-system/extensions/core/root-files/settings.local.json`, `agent-system/extensions/core/root-files/settings.json`, `agent-system/extensions/core/hooks/guard-destructive-git.sh`, `agent-system/extensions/email/hooks/mail-guard.sh`, `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh`, `agent-system/extensions/cslib/agents/cslib-implementation-agent.md`, `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`, `agent-system/extensions/core/agents/*.md`, `agent-system/extensions/core/scripts/memory-harvest.sh`, `agent-system/extensions/core/rules/git-workflow.md`, `agent-system/extensions/core/rules/no-task-references-in-deliverables.md`
  - Prior research (this repo): `specs/archive/684_pretooluse_hook_pr_block/reports/01_pretooluse-hook-research.md` (PreToolUse blocking mechanism), `specs/archive/416_enforce_skill_delegation_for_plan_artifacts/reports/01_skill-delegation-enforcement.md` (PostToolUse vs PreToolUse trade-offs)
  - Live web: `code.claude.com/docs/en/hooks` (confirms exit-code-2 semantics for Write/Edit)
  - Repo-wide `grep -rE` measurements (this session, commands quoted in Appendix)
**Artifacts**: - `specs/941_purge_and_enforce_no_task_references/reports/01_purge-and-enforce-no-task-references.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Baseline re-measured and confirmed close to the settled numbers**: `agent-system/extensions/**` 568 occ (was 567), `.opencode/**` 610 occ (exact match), `lua/**` 32 occ (exact match), `.memory/**` 18 occ (exact match) — total 1,228 (~1,227). The `specs/{NNN}_{slug}/` path-citation count (503 occ / 221 files, was 474) and `sess_*` literal count (126 files, was 121) also reconcile once `specs/**` itself is correctly excluded from the scan (an early scan pass in this session double-counted specs/ before the exclusion filter was fixed — see Appendix).
- **A concrete, load-bearing exemption-taxonomy failure already exists in the tree**: `agent-system/extensions/core/rules/git-workflow.md` itself — the file that *defines* the sanctioned `task {N}: {action}` commit convention — contains `task 259 phase 2: implement modal semantics evaluator`, which trips the hook's own `PHASE_PATTERN` (`task N phase P`). The canonical example of the sanctioned pattern is, today, indistinguishable from a violation. Any lint/blocking design that doesn't special-case this is self-defeating.
- **The test-file path in the task description is wrong and must be corrected in planning**: the test suite lives at `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` (declared in `manifest.json` under `provides.scripts`, not `provides.hooks`), not `agent-system/extensions/core/hooks/tests/...`. It currently has **zero** exemption-category test cases (only a `specs/**` path exemption) — extending it for P2/P3 is real, un-started work.
- **The blocking-hook mechanism question (Part D) has an authoritative in-repo precedent already settled by prior research**: `exit code 2` (stderr fed back to Claude) is the reliable PreToolUse block, confirmed by this repo's own `specs/archive/684_.../reports/01_pretooluse-hook-research.md` and by live docs fetched this session — it works uniformly for Bash, Write, Edit, and MCP tools. `permissionDecision: "deny"` is documented-risky specifically when the tool is bare-allow-listed, which **Write and Edit both are** in `settings.json`'s `permissions.allow` (`"Write"`, `"Edit"` as unconditional entries, same shape as the `Bash(git:*)` entry that `guard-destructive-git.sh` explicitly avoids `permissionDecision: deny` for). Note the codebase is internally inconsistent here: `agent-system/extensions/email/hooks/mail-guard.sh` *does* use `permissionDecision: "deny"` successfully today (for un-allow-listed raw `himalaya`/`msmtp` substrings) — that is a different case (denying a substring never captured by a bare allow entry), not a counterexample.
- **The agent-contract gap (Part E) is confirmed exactly as described, with one correction**: only `cslib-implementation-agent.md` (bullet 20) and `cslib-implementation-hard-agent.md` (bullet 11) carry the MUST-NOT bullet. Of the core agents, only `general-implementation-agent.md` and `general-implementation-hard-agent.md` need it added — `meta-builder-agent.md` is structurally exempt (Rule 1 forbids it from writing outside `specs/**` at all; it never authors deliverables directly), and `planner-agent.md`/`reviser-agent.md` write exclusively to `specs/**/plans/` (already exempt), so they don't need the bullet either. This narrows P4's actual edit surface from "5 core agents" to 2.
- **A genuine, previously-unverified enforcement-coverage gap exists for `.memory/**`**: memory files are sometimes written via a Bash-tool heredoc (`cat > "$mem_file" <<MEMEOF` in `memory-harvest.sh`) rather than the Claude `Write`/`Edit` tool. A `Write|Edit`-matcher PreToolUse hook structurally cannot see that path. `memory-harvest.sh` itself notes it is "presently uncalled" — the live path is `skill-todo`'s inline harvest logic — but whether *that* codepath uses the `Write` tool or another heredoc needs empirical verification during implementation before P3 can claim `.memory/**` coverage.

## Context & Scope

This is the research pass for the two-part PREVENTION + PURGE task described in `specs/state.json` (project 941). The task description is long and settles most policy questions already (staged enforcement, purge scope = everything outside `specs/**`, `.memory/**` is deliverables not metadata). This report does not re-litigate those decisions; it re-measures the baseline, fills in the exemption taxonomy with verified concrete examples, nails down exact file paths/wiring points for the new lint script and the blocking-hook flip, confirms/corrects the agent-contract gap claim, and proposes a concrete phase decomposition sized for single-agent-run bounds (~100-500 lines of diff per phase, per the `H8` phase-sizing convention this codebase already uses for `--hard` planning).

No edits were made to any deliverable file during this research pass.

## Findings

### A. Re-measured baseline

Using the hook's own patterns, re-derived from `agent-system/extensions/core/hooks/validate-no-task-references.sh`:

```bash
TASK_SEP='([[:space:]]+#?|[-_#])'
TASK_PATTERN="\\b[Tt]asks?${TASK_SEP}[0-9]+(-[0-9]+)?\\b"
```

| Tree | Occurrences (grep -c) | Files |
|------|------------------------|-------|
| `agent-system/extensions/**` | 568 | 167 |
| `.opencode/**` | 610 | 188 |
| `lua/**` | 32 | 13 |
| `.memory/**` | 18 | 17 |
| **Total** | **1,228** | **385** |

Breakdown of `agent-system/extensions/` by extension (occurrences / files):

| Extension | Occ | Files |
|-----------|-----|-------|
| `core` | 352 | 84 |
| `literature` | 94 | 26 |
| `email` | 38 | 9 |
| `founder` | 21 | 20 |
| `present` | 18 | 6 |
| `cslib` | 11 | 3 |
| `memory` | 11 | 3 |
| `web` | 9 | 4 |
| `nvim` | 5 | 3 |
| `formal` | 4 | 4 |
| `lean` | 3 | 3 |
| `nix` | 2 | 2 |

`core/` itself, by subdirectory (occ / files): `context/` 147/31, `docs/` 70/12, `scripts/` 51/12, `skills/` 25/11, `commands/` 28/7, `agents/` 20/4, `rules/` 6/3, `hooks/` 3/3, `merge-sources/` 2/1.

`.opencode/` by subdirectory (occ / files): `extensions/` 275/95, `context/` 210/50, `docs/` 47/13, `skills/` 27/8, `commands/` 16/5, `agent/` 16/3, `scripts/` 10/7, `rules/` 4/2, `hooks/` 3/3.

`lua/**` (32 occ, 13 files) is almost entirely simple provenance comments, e.g.:
- `lua/neotex/plugins/text/lean.lua:135`: `-- See: Task #41 - fix_leanls_lsp_client_exit_error`
- `lua/neotex/plugins/tools/himalaya/ui/email_reader.lua:49`: `-- Per task 56: NO single-letter action mappings in email reader`
- `lua/neotex/plugins/tools/himalaya/ui/email_list.lua:172`: `--- Toggle all threads expand/collapse (Task #88)`
- `lua/neotex/plugins/tools/himalaya/config/ui.lua`: three separate `Task #88` provenance comments

`.memory/**` (18 occ, 17 files) — a scan of filenames confirms these are all in `10-Memories/*.md` bodies (agent-authored memory content), consistent with the settled decision that `.memory/**` is deliverables.

**Secondary classes** (re-measured, methodology note in Appendix): `specs/{NNN}_{slug}/` path citations outside `specs/**` = 503 occurrences / 221 files (breakdown: `.opencode` 118 files, `agent-system` 89 files, `.memory` 13 files, `lua` 1 file); `sess_*` literal citations outside `specs/**` = 126 files (`.opencode` 83, `agent-system` 43). Both are in the same order of magnitude as the settled baseline (474/121) — the small drift is expected per the task description's own "re-measure, do not trust these as final" instruction, not a discrepancy worth investigating further.

### B. Exemption taxonomy — verified categories and a self-defeating example

Four categories are verified present in the tree, with concrete examples:

1. **Git commit-message convention examples** — sanctioned by `rules/git-workflow.md` itself:
   - `git-workflow.md:104`: `` `task 334: complete research` ``
   - `git-workflow.md:222`: `` `task 334: create LaTeX documentation for Logos system` ``
   - `git-workflow.md:228`: `` `task 259 phase 2: implement modal semantics evaluator` `` — **this one trips `PHASE_PATTERN`** (`task N phase P`), inside the very file that defines the convention. This is the strongest evidence in this research that the taxonomy must live in one shared place, not be re-derived independently by a lint script and a hook.

2. **Command-usage examples** — the `/research`, `/learn --task`, multi-task syntax docs:
   - `agent-system/extensions/core/README.md:46`: `` `/research 7, 22-24` ``
   - `agent-system/extensions/core/merge-sources/claudemd.md:119`: `` `/research 7, 22-24, 59` ``
   - `agent-system/extensions/core/context/patterns/skill-lifecycle.md:157`: `` `/research 7, 22, 24` ``
   - `agent-system/extensions/core/context/patterns/multi-task-operations.md`: multiple, e.g. `Skill(skill-researcher, task 7)`, `task 7:  "Research completed: ..."`, `If agent for task 23 fails:`

3. **Illustrative sample agent output / format examples** — same `multi-task-operations.md` block above is dual-purpose (both a command-usage example and a sample-output example); also the rule file's own **Before**-anti-pattern illustration in `no-task-references-in-deliverables.md` itself (`"## 13. Index Freshness, Reindex, and the Absence of an Auto-Indexer (tasks 823-824)"` / `"**Architecture context (task 35)**"`) — a legitimate third sub-case: a rule quoting a *real, historical* anti-pattern as a negative example. This is not the same as case 2/3's forward-looking illustrations; it needs its own "quoted historical anti-pattern, illustrative only" carve-out or it will flag the rule file that defines the whole policy.

4. **Placeholder-bearing prose** (`{N}`, `{NNN}`, `MM`) — already the convention throughout `CLAUDE.md`/`artifact-formats.md`; the current `TASK_PATTERN` requires `[0-9]+` after the separator so placeholder tokens do not currently false-positive. This category is a **constraint on future pattern changes** (don't broaden the digit-requirement), not an existing violation to fix.

**Two originally-named occurrences** (re-confirmed, exact quotes, both inside `agent-system/extensions/core/`, so both fall within the Phase 1 purge below rather than needing a separate phase):
- `agent-system/extensions/core/commands/orchestrate.md`: `` `/orchestrate 785,787` where task 785 and task 787 were each created independently) have no creation-time `` — the cross-batch collision illustration.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`: `` # Fresh start: create guard atomically via init-marker (task 808). A plain `` — pure provenance, mechanism (`init-marker`'s mkdir-gate + tmp-mv payload) already fully described in the surrounding comment.

**Recommendation for a shared definition**: the taxonomy (4 categories above, plus the two named-occurrence rewrites) should live as a single markdown table in `rules/no-task-references-in-deliverables.md` (per the task description's own instruction), and both `check-task-references.sh` and `validate-no-task-references.sh` should implement matching logic driven from the *same* regex constants — the cleanest mechanism given both are bash scripts is a small shared sourced file (e.g. `agent-system/extensions/core/scripts/lib/task-reference-patterns.sh` defining `TASK_PATTERN`/`PHASE_PATTERN`/exemption-glob arrays) that both `source`. Today `TASK_PATTERN`/`PHASE_PATTERN` are defined inline in the hook only; no such shared file exists yet.

### C. Lint script design — precedent and exact wiring points

`check-extension-docs.sh` precedent confirmed:
- Structure: `set -uo pipefail`, `--quiet` flag via `[[ "${1:-}" == "--quiet" ]]`, `REPO_ROOT`/`EXT_DIR` resolution via `deploy-root-guard.sh` (with a documented `REPO_ROOT=$(pwd)` override escape hatch for verification runs), `info()`/`fail()` helpers, a `FAILURES` counter, exit `0` on all-pass / `1` on any-fail.
- **Scope difference to design around**: `check-extension-docs.sh` walks `$EXT_DIR/*/` (i.e. `agent-system/extensions/*/` only). `check-task-references.sh` needs a structurally different walk — the four purge trees (`agent-system/extensions/**`, `.opencode/**`, `lua/**`, `.memory/**`) are siblings, not all under one root, and `specs/**` must be excluded unconditionally regardless of which tree it's nested under (it never is, but the exclusion logic should still mirror the hook's `specs/*|*/specs/*` case pattern for consistency). Recommend enumerating via `git ls-files` per tree (matching `check-extension-docs.sh`'s own `_git_deployed_files` helper, Rules J/K/L/M) rather than `find`, so gitignored runtime artifacts are naturally excluded.
- `verify-deploy.sh` gate numbering: currently exactly 3 `say "N. ..."` gates — `1. Event-store files`, `2. Hook registrations`, `3. Doc-lint (check-extension-docs.sh --quiet)`. A new task-reference gate is a natural `4.` (or `3.5` inserted before the summary), invoked the same way: `bash "$CLAUDE_DIR/scripts/check-task-references.sh" --quiet`, gated with the same `[SKIP] ... deploy consumer, not the source store` guard `check-extension-docs.sh`'s own gate uses.
- `manifest.json` `provides.scripts` currently lists 67 entries alphabetically (including `check-extension-docs.sh` itself and the misdocumented-location test `tests/test-validate-no-task-references.sh`); `check-task-references.sh` is a one-line addition to that array.
- `root-files/settings.local.json` permission-entry precedent (exact lines to mirror):
  ```
  "Bash(bash .claude/scripts/check-extension-docs.sh)",
  "Bash(bash .claude/scripts/check-extension-docs.sh --quiet)",
  "Bash(bash /home/benjamin/.config/nvim/.claude/scripts/check-extension-docs.sh)",
  ```
  Three parallel entries (bare, `--quiet`, absolute-path form) for `check-task-references.sh`.

### D. Blocking-hook mechanism — settled by prior in-repo research, reconfirmed live

The task description's uncertainty here is already resolved by `specs/archive/684_pretooluse_hook_pr_block/reports/01_pretooluse-hook-research.md`, an earlier research report in this same repo, and reconfirmed against live docs this session (`code.claude.com/docs/en/hooks`):

- **JSON shape** for `permissionDecision`: `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "..."}}`. Applies to any tool (matcher decides which tools trigger the hook), not just Bash.
- **Exit code 2** blocks uniformly across Bash, Write, Edit, and MCP tools — stderr text is fed back to Claude as an error message, and (per official docs, quoted in the archived report) "takes precedence over allow rules... stops the tool call before permission rules are evaluated."
- **The risk with `permissionDecision: deny`**: three closed GitHub issues (#4669, #13214, #18312) document it being ignored/bypassed specifically when the exact tool call matches an *allow-listed* permission rule. `settings.json`'s `permissions.allow` contains bare `"Write"` and `"Edit"` entries (unconditional, same shape as the `"Bash(git:*)"` entry `guard-destructive-git.sh`'s own header comment explicitly cites as the reason it uses exit-code-2 instead of `permissionDecision: deny`). **Recommendation: use exit code 2 for the P3 blocking flip**, matching both this repo's own `guard-destructive-git.sh` precedent and the archived task-684 research's explicit recommendation for exactly this "tool is bare-allow-listed" situation.
- **Existing precedent inconsistency to note (not to silently "fix" without a decision)**: `agent-system/extensions/email/hooks/mail-guard.sh` *does* use `permissionDecision: "deny"` successfully in production, for `Bash` commands matching raw `himalaya`/`msmtp`/`secret-tool` substrings. This is not a counterexample to the recommendation above — those substrings are never matched by the bare `Bash(git:*)`-shaped allow entries, so the documented bug's precondition doesn't apply — but a planner should note both patterns exist in the codebase today and pick one deliberately for the new hook rather than copying whichever file is nearest.
- `settings.json`'s only current inline `PreToolUse`/`Write` entry (the `state.json` guard) is a **pass-through that always emits `permissionDecision: "allow"`** regardless of the file matched — it is not a working example of a deny gate, just a notification-shaped no-op. It should not be used as a structural template for the new hook.

**Test-file correction**: the task description asked to "examine `agent-system/extensions/core/hooks/tests/test-validate-no-task-references.sh`" — **that path does not exist**. The actual file is `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` (declared in `manifest.json` as `tests/test-validate-no-task-references.sh` under `provides.scripts`). It follows the `context/standards/shell-script-testing.md` convention (`pass()`/`fail()`/`info()` helpers, `mktemp -d` isolation, drives the hook as a real subprocess via a synthetic JSON payload piped on stdin, never instruments the hook itself). It currently has 10 positive fixtures, 7 negative fixtures, 2 `specs/**`-exemption fixtures, and 2 degenerate-input fixtures — **zero fixtures for any P2 exemption category** (commit-convention examples, command-usage examples, or the historical-anti-pattern-quote case found in Finding B). Extending this suite for both the deny path and every P2 category is genuine, unstarted work, not a mechanical rename.

### E. Agent-contract gap — confirmed with a narrower fix surface than described

Confirmed: the MUST-NOT bullet exists in exactly two files, with this exact wording (to reuse verbatim):

- `cslib-implementation-agent.md` bullet 20: `Reference task numbers ("task N", "tasks N-M") in files outside specs/** -- see .claude/rules/no-task-references-in-deliverables.md; reference durable anchors (filenames, section headings) instead`
- `cslib-implementation-hard-agent.md` bullet 11: identical wording.

Of the core agents (`agent-system/extensions/core/agents/*.md`):

| Agent | Writes outside `specs/**`? | Needs the bullet? |
|-------|------------------------------|--------------------|
| `general-implementation-agent.md` | Yes (implements plans against any file) | **Yes — missing today** |
| `general-implementation-hard-agent.md` | Yes (same) | **Yes — missing today** |
| `meta-builder-agent.md` | **No** — Rule 1 explicitly forbids writing any file outside `{target_root}/specs/`; it only ever creates task descriptions, never implements | No — structurally exempt |
| `planner-agent.md` | No — writes only `specs/{NNN}_{SLUG}/plans/**` | No — exempt tree only |
| `reviser-agent.md` | No — writes only `specs/{NNN}_{SLUG}/plans/**` | No — exempt tree only |
| `code-reviewer-agent.md` | No `Write` references found at all (read-only review agent) | No |
| `spawn-agent.md`, `synthesis-agent.md`, `general-research-agent.md`, `general-research-hard-agent.md` | Write only `specs/**` artifacts | No |

This narrows P4's actual edit surface to **2 files** (`general-implementation-agent.md`, `general-implementation-hard-agent.md`), not the 5 the task description names as candidates. Exact insertion point confirmed in both files: each already has a `**MUST NOT**:` list ending with a `source-store-deploy-boundary.md` bullet (bullet 6 in both), which is the natural place to append the new bullet as the next-numbered item, reusing the cslib wording verbatim.

**Extension implementation agents** (not in the task description's scope, but worth flagging as the same gap class): `neovim-implementation-agent`, `nix-implementation-agent`, `email-implementation-agent` also author files outside `specs/**` and also lack the bullet. Out of scope for this task per its stated boundaries (core agents only), but should be logged as a follow-up.

### F. Phasing and sizing

~1,227 occurrences / 385 files is far beyond one agent run. Recommended decomposition (mirrors the `H8` phase-sizing convention: bound each phase to roughly one agent run's worth of diff, ~100-500 lines):

**Part 1 — Prevention (must land first, in this internal order)**:
1. **P1**: author `check-task-references.sh` + wire into `manifest.json`/`verify-deploy.sh`/`settings.local.json` (mechanical, small — Finding C gives exact insertion points).
2. **P2 + P5**: design and document the shared exemption taxonomy in `rules/no-task-references-in-deliverables.md` (the 4 categories + the historical-anti-pattern-quote carve-out from Finding B), including the rewrite of `git-workflow.md`'s own `task 259 phase 2` example if that's the chosen resolution (vs. carving out an explicit "convention documentation" exemption instead — this is a judgment call the plan should make explicit, not defer). This phase gates every later purge phase, since the lint script (P1) needs the taxonomy to avoid false-positiving on sanctioned examples.

**Part 2 — Purge (mechanical bulk of the work, phased by tree, each phase git-committed independently per the task description's T3)**:

| Phase | Target | Occ | Files | Character |
|-------|--------|-----|-------|-----------|
| 3 | `agent-system/extensions/core/context/` | 147 | 31 | mostly illustrative/provenance in docs; largest single subdir |
| 4 | `agent-system/extensions/core/{docs,scripts,skills,commands,agents,rules,hooks,merge-sources}/` | 205 | 53 | includes the two T2 named occurrences (`commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`) — verify both explicitly during this phase |
| 5 | `agent-system/extensions/literature/` | 94 | 26 | largest non-core extension |
| 6 | `agent-system/extensions/{cslib,email,formal,founder,lean,memory,nix,nvim,present,web}/` | 122 | 57 | remaining extensions, combined (each individually small) |
| 7 | `lua/**` | 32 | 13 | mechanical — almost all bare provenance comments, low judgment needed |
| 8 | `.memory/**` | 18 | 17 | agent-authored memory bodies; convert provenance to durable anchors |
| 9 | `.opencode/extensions/` | 275 | 95 | hand-ported mirror of agent-system extensions — edited **directly in place** (not via agent-system), per the source-store rule |
| 10 | `.opencode/context/` | 210 | 50 | second-largest single subdir in the whole purge |
| 11 | `.opencode/{docs,skills,agent,commands,scripts,hooks,rules}/` | 123 | 39 | remaining `.opencode` |

Phases 3-4 and 9-11 are the highest-judgment phases (docs/context prose requiring real triage between PROVENANCE/ILLUSTRATIVE/SANCTIONED per T1); phases 7-8 are the most mechanical (bulk find-and-convert of simple comment-style provenance, plausibly scriptable with a sed pass reviewed by an agent rather than requiring per-site LLM judgment).

**Closing phases**:
12. **P4**: add the MUST-NOT bullet to `general-implementation-agent.md` and `general-implementation-hard-agent.md` (Finding E — small, mechanical, can land any time before Phase 13, doesn't block the purge).
13. **P3**: flip `validate-no-task-references.sh` to a blocking PreToolUse hook using **exit code 2** (Finding D), and extend `agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh` (correct path) to cover the deny path plus every P2 exemption category. This is explicitly LAST, gated on Phases 1-12 all being green, per the task description's staged-enforcement decision. Before claiming `.memory/**` coverage, empirically verify whether `skill-todo`'s inline harvest logic (the live memory-write path, since `memory-harvest.sh` is "presently uncalled") writes via the `Write` tool or a Bash heredoc — if the latter, the write-time gate structurally cannot see it and that gap needs to be called out rather than silently assumed closed.

## Decisions

- Use **exit code 2**, not `permissionDecision: deny`, for the P3 blocking hook — settled by this repo's own prior research (task-684 archive) and reconfirmed against live docs; matches `guard-destructive-git.sh`'s existing precedent for the same "tool is bare-allow-listed" situation.
- Treat the `git-workflow.md` self-trip (`task 259 phase 2`) as a required design input for P2, not an edge case to discover later — the plan must explicitly decide whether to rewrite that example or carve out a "canonical convention documentation" exemption.
- Narrow P4's scope to `general-implementation-agent.md` + `general-implementation-hard-agent.md` only, per the corrected agent-authoring-surface analysis in Finding E.
- Use the corrected test-file path (`agent-system/extensions/core/scripts/tests/test-validate-no-task-references.sh`) throughout planning; the task description's stated path is wrong.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Purge phases silently delete provenance that carries real explanatory weight (T1's "do not silently delete" instruction) | Each phase's agent must convert, not delete — use the T1 taxonomy buckets explicitly per-site |
| A rewritten/converted `git-workflow.md` example accidentally breaks the documented convention it's teaching | Treat this file's Phase-4 edit as its own reviewed sub-step, not folded into the bulk core purge |
| Blocking hook (P3) ships against a tree that isn't actually clean, due to a missed occurrence in a late-arriving edit during the purge window | P3 is explicitly gated last; re-run `check-task-references.sh` (P1) with zero exit as the literal gate condition before flipping |
| `.memory/**` write-time coverage is assumed rather than verified | Explicit verification step in Phase 13 before claiming the hook covers memory writes |
| Lint script (`check-task-references.sh`) and hook (`validate-no-task-references.sh`) drift into divergent regex logic over time | Extract `TASK_PATTERN`/`PHASE_PATTERN`/exemption logic into one shared sourced file both consume (Finding B recommendation) |

## Context Extension Recommendations

- **Topic**: shared regex/taxonomy source for task-reference detection.
- **Gap**: no `agent-system/extensions/core/scripts/lib/` (or similar) shared-constants location currently exists for this pattern family; `TASK_PATTERN`/`PHASE_PATTERN` are defined inline only in the hook.
- **Recommendation**: if this task's plan creates the shared file suggested in Finding B, register it as a new context/pattern entry so future audits of hook/script pattern drift can find it via `index.json`.

## Appendix

### Measurement methodology note

An early scan pass in this session used `grep -v '^\./specs/'` to exclude the `specs/` tree while scanning from `.`, but this repo's `grep -r .` emits paths **without** a leading `./` (e.g. `specs/TODO.md`, not `./specs/TODO.md`), so that exclusion silently did nothing and inflated the secondary-class counts (513 files / 1,920 occurrences observed for `sess_*` and `specs/{NNN}_{slug}/` respectively). Corrected exclusion (`grep -v '^specs/'`) reproduced counts consistent with the settled baseline (126 files / 503 occurrences). This is noted here so the implementation phase doesn't re-derive the same false alarm.

### Search commands used

```bash
TASK_SEP='([[:space:]]+#?|[-_#])'
TASK_PATTERN="\\b[Tt]asks?${TASK_SEP}[0-9]+(-[0-9]+)?\\b"
grep -rEi "$TASK_PATTERN" agent-system/extensions/ | wc -l
grep -rEi "$TASK_PATTERN" .opencode/ | wc -l
grep -rEi "$TASK_PATTERN" lua/ | wc -l
grep -rEi "$TASK_PATTERN" .memory/ | wc -l
grep -rEo "specs/[0-9]{2,4}_[a-zA-Z_-]+" . --include="*.md" --include="*.sh" | grep -v '^\.git/' | grep -v '^specs/'
grep -rl "sess_[0-9]" . --include="*.md" --include="*.sh" --include="*.json" --include="*.lua" | grep -v '^\.git/' | grep -v '^specs/'
```

### References

- `code.claude.com/docs/en/hooks` (fetched live this session; PreToolUse `permissionDecision` shape and exit-code-2 semantics)
- `specs/archive/684_pretooluse_hook_pr_block/reports/01_pretooluse-hook-research.md`
- `specs/archive/416_enforce_skill_delegation_for_plan_artifacts/reports/01_skill-delegation-enforcement.md`
