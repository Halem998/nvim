# Research Report: Task #819

**Task**: 819 - Add the email extension to .claude/extensions.json so it is actually loaded
**Started**: 2026-07-05T05:20:00Z
**Completed**: 2026-07-05T05:35:00Z
**Effort**: N/A (research only; recommended implementation is a no-op)
**Dependencies**: None
**Sources/Inputs**: Codebase (`.claude/extensions.json`, `.claude/extensions/email/**`, `.claude/scripts/check-extension-docs.sh`), cross-repo inspection (`~/.dotfiles/.claude/`), git history, `specs/reviews/review-2026-07-04.md`, `specs/TODO.md`/`state.json`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **RECOMMENDATION: Do NOT load the email extension into this repo's (`~/.config/nvim`) `.claude/extensions.json`.** The gating condition in the task description ("Only do this if the email extension is intended to be loaded in this repo") resolves to **no**.
- The email extension is **already loaded and live** in its actual intended consumer repo, `~/.dotfiles` — `~/.dotfiles/.claude/extensions.json` lists `"email"` as active, sourced explicitly from `source_dir: "/home/benjamin/.config/nvim/.claude/extensions/email"`, and `~/.dotfiles/.claude/CLAUDE.md` already contains the fully-propagated "## Email Extension" section.
- This nvim repo (`~/.config/nvim`) functions as the **authoring source** for a library of shared extensions (core, cslib, email, epidemiology, formal, latex, lean, nix, nvim, python, z3, etc. all live under `.claude/extensions/` here), only a subset of which (`core`, `nix`, `memory`, `nvim`) are also loaded *into this same repo*. `email` is authored here but designed for a different consuming repo.
- The extension's own `README.md` explicitly states: *"This extension authors and ships the `.claude/extensions/email/` directory; loading it into a consuming repo ... is a separate, later step and is out of scope"* and *"this extension is authored and doc-lint-verified only; it has not been loaded into this or any consuming repo [nvim's own]. Loading ... is a deliberate, separate step performed later by a user."*
- There are **zero** `task_type: "email"` tasks anywhere in this repo's `specs/state.json` (checked via `jq`). The one email-adjacent task here, #78 ("Fix Himalaya SMTP authentication failure ... via Himalaya (`<leader>me`)"), is correctly typed `neovim` — it is about troubleshooting the Neovim Himalaya *plugin* keymap/config, an unrelated concern to the AI-triage/wrapper-binary email extension.
- The flagged "routing target not deployed: skill-email-implementation" warning is **not a bug** — it is the designed, non-failing behavior of `check-extension-docs.sh` for an authored-but-not-installed extension (Rule C: `WARN` when uninstalled vs. `FAIL` when installed). Running the script confirms `[email] ... PASS` overall, with the WARN as its only (expected) output line.
- Because intent = no, the correct implementation for task 819 is a **no-op that documents the decision** (see Deliverable below), not an `extensions.json` edit.

## Context & Scope

Task 819 is conditional: only add `email` to `.claude/extensions.json` (and thereby propagate `EXTENSION.md` into `.claude/CLAUDE.md`) if the extension is actually intended to run in *this* repo (`/home/benjamin/.config/nvim`). The review that spawned this task (`specs/reviews/review-2026-07-04.md`, finding 3 of the recommendations) explicitly flagged this as "(Separate/known) ... if it is meant to be loaded ... (pre-existing, out of this diff's scope)" — i.e., the reviewer did not assert intent, only that the gap is observable.

Two things needed resolving: (1) intent (gating), and (2) mechanics if intent were yes. Investigation fully resolved (1) as **no**, which makes (2) moot for this repo (mechanics are summarized below only for completeness/audit trail).

## Findings

### 1. Current `.claude/extensions.json` state (this repo)

`.claude/extensions.json` (`extensions` key) currently has exactly four entries: `core`, `nix`, `memory`, `nvim`. No `email` key exists. Each entry's `source_dir` for a same-repo extension is `/home/benjamin/.config/nvim/.claude/extensions/{name}` — i.e., normally source and consumer are the same repo.

### 2. The email extension directory (`.claude/extensions/email/`) — what it provides

`manifest.json`:
```json
{
  "name": "email", "task_type": "email", "dependencies": ["core"],
  "keyword_overrides": {"email": {"keywords": ["inbox","email","gmail","himalaya","notmuch",
    "unsubscribe","junk mail","draft reply","mbsync","aerc","mail triage","logos","protonmail","proton"],
    "aliases": ["mail","mailbox"]}},
  "provides": {
    "agents": ["email-implementation-agent.md"],
    "skills": ["skill-email-implementation","skill-email-cleanup","skill-email-sync"],
    "commands": ["email.md"], "context": ["project/email"], "hooks": ["mail-guard.sh"]
  },
  "routing": {"research":{"email":"skill-researcher"},"plan":{"email":"skill-planner"},
    "implement":{"email":"skill-email-implementation"}},
  "merge_targets": {
    "claudemd": {"source":"EXTENSION.md","target":".claude/CLAUDE.md","section_id":"extension_email"},
    "settings": {"source":"settings-fragment.json","target":".claude/settings.local.json"},
    "index": {"source":"index-entries.json","target":".claude/context/index.json"}
  }
}
```
It provides an AI email-triage workflow (`/email`, `/email --all`, `/email --archive`, `/email --sync`) over Himalaya/notmuch, mutating only through five nix-built wrapper binaries (`email-census`, `email-classify`, `email-unsubscribe-extract`, `email-archive-confirmed`, `email-delete-confirmed`) built by `~/.dotfiles`' `modules/home/email/agent-tools.nix`. `hooks/mail-guard.sh` is a `PreToolUse` Bash-tool guard denying raw `himalaya`/`msmtp`/`secret-tool`/`rm *Mail*` calls.

`README.md` (verbatim, decisive): *"This extension authors and ships the `.claude/extensions/email/` directory; loading it into a consuming repo (via the extension picker) is a separate, later step and is out of scope for the task that authored this README."* And its closing "Scope Note": *"This extension is authored and doc-lint-verified only; it has not been loaded into this or any consuming repo. Loading (via the extension picker) is a deliberate, separate step performed later by a user."* This is an explicit statement by the extension's own authors that loading is deferred and repo-specific, not automatic.

### 3. The email extension IS already loaded — in `~/.dotfiles`, not here

`~/.dotfiles/.claude/extensions.json` lists extensions `core, email, memory, nix, nvim, python`. Its `email` entry:
```json
{
  "status": "active",
  "loaded_at": "2026-07-04T20:01:54Z",
  "source_dir": "/home/benjamin/.config/nvim/.claude/extensions/email",
  "installed_files": [
    ".claude/agents/email-implementation-agent.md", ".claude/commands/email.md",
    ".claude/skills/skill-email-implementation/SKILL.md",
    ".claude/skills/skill-email-cleanup/SKILL.md", ".claude/skills/skill-email-sync/SKILL.md",
    ".claude/context/project/email/...(6 files)...", ".claude/hooks/mail-guard.sh",
    ".claude/extensions/email/manifest.json"
  ]
}
```
`source_dir` is an **absolute, cross-repo path pointing at this nvim repo's copy** — proving the nvim repo is the authoring/source location and `.dotfiles` is the intended consumer. `~/.dotfiles/.claude/skills/` on disk confirms all three skills (`skill-email-implementation`, `skill-email-cleanup`, `skill-email-sync`) and the agent (`email-implementation-agent.md`) are actually deployed there. `~/.dotfiles/.claude/CLAUDE.md` already contains the full, propagated "## Email Extension" section (verified via `grep`), i.e., the exact `EXTENSION.md`→`CLAUDE.md` merge this task is asking to make "observable" **already happened, in the correct repo**.

`install-extension.sh`'s usage (`install-extension.sh <extension-directory>`) confirms pointing the installer at an arbitrary directory — including one in a different repo — is a normal, supported invocation, not a hack.

(Minor, non-blocking drift noted for completeness: `.dotfiles`'s cached `extensions/email/manifest.json` copy has an older `keyword_overrides.email.keywords` list missing `logos`/`protonmail`/`proton`, added later here by nvim tasks 815/816. This is a `.dotfiles`-side staleness question, out of scope for task 819, and does not change the intent conclusion.)

### 4. No organic email-task-type presence in this repo

`jq '[.active_projects[] | select(.task_type=="email")] | length' specs/state.json` → `0`. The single email-adjacent task in this repo, #78 ("Fix Himalaya SMTP authentication failure when sending emails via Himalaya (`<leader>me`)"), is `task_type: "neovim"` and concerns the Neovim Himalaya-plugin keymap/SMTP config — a different, already-correctly-routed concern from the AI-agent email-triage extension. Loading the extension here would retroactively make `email`-flavored keywords (`inbox`, `gmail`, `himalaya`, `mbsync`, ...) auto-classify *future* `/task` creations in this repo as `task_type: email` even though this repo has no nix-built wrapper binaries, no live mailbox config, and no prior use of the `/email` command — a routing footgun with no corresponding capability.

### 5. The flagged doc-lint warning is by design, not a defect

`.claude/scripts/check-extension-docs.sh` (`check_routing_consistency`, lines ~154-240) documents its own policy explicitly in a comment: *"FAIL if the extension is installed but the target is not deployed; WARN (info) if the extension is not installed (expected undeployed state)."* Running it:
```
[email]
  WARN: routing target not deployed (extension not installed): skill-email-implementation
  OK
...
email           PASS
```
`[email]` is `PASS` overall; the WARN is the single expected, non-blocking line for an authored-but-uninstalled extension. (The unrelated `[core] FAIL` lines in the same run — stale script references `literature-briefing-invoke.sh`, `orchestrator-postflight.sh`, `task-lock.sh` — are pre-existing core doc-lint issues unrelated to email; not in scope here.)

### Codebase Patterns

- Extensions are authored as self-contained packages under `.claude/extensions/{name}/` and *loaded* into a repo by adding an entry to that repo's own `.claude/extensions.json` (see `.claude/docs/architecture/extension-system.md`, `install-extension.sh <extension-directory>`).
- The normal case has `source_dir` pointing within the same repo (e.g., this repo's own `nix`, `memory`, `nvim` entries). The `email` extension is the cross-repo case: authored in `~/.config/nvim`, consumed in `~/.dotfiles`.
- `merge_targets.claudemd` (`EXTENSION.md` → `.claude/CLAUDE.md`, `section_id: extension_email`) is the mechanism task 819 describes wanting to make "observable" — and it already is observable, correctly, in `~/.dotfiles/.claude/CLAUDE.md`.

### External Resources

None consulted; this was a purely local, cross-repo filesystem investigation (two repos on the same machine).

### Recommendations

1. **Do not edit `.claude/extensions.json` in this repo.** No `email` entry should be added.
2. **Implementation should be a no-op that documents this decision**, per the task's own instruction ("in which case the implementation should be a no-op that documents the decision"). Suggested concrete action for `/plan` + `/implement`:
   - Mark task 819 `[COMPLETED]` with a `completion_summary` stating: "Investigated; email extension is intentionally not loaded in this repo. It is authored here (`.claude/extensions/email/`) but is loaded and live in its actual consumer, `~/.dotfiles` (`source_dir` cross-repo reference confirmed). The `skill-email-implementation not deployed` warning is expected, non-blocking (`WARN`, not `FAIL`) behavior of `check-extension-docs.sh` for an authored-but-uninstalled extension, and `[email]` reports overall `PASS`. No files changed."
   - No `extensions.json`, `CLAUDE.md`, or `settings.local.json` edits are needed or wanted.
3. If a persistent decision record is desired beyond the task's own completion summary, a one-line note could be added to `.claude/extensions/email/README.md`'s existing "Scope Note" section (e.g., "Evaluated for loading into `~/.config/nvim` on 2026-07-05 (task 819); decision: do not load — see `~/.dotfiles` for the live consumer.") This is optional polish, not required for task closure.

## Decisions

- **Intent = NO.** The email extension is not intended to be loaded into `~/.config/nvim`'s `.claude/extensions.json`. It is intended for, and already active in, `~/.dotfiles`.
- **Mechanics (moot, not executed)**: had intent been yes, the edit would have been: add an `"email"` key to `.claude/extensions.json`'s `extensions` object (following the same shape as the `nix`/`memory` entries — `installed_dirs`, `merged_sections.index.paths` from `index-entries.json`, `merged_sections.settings` from `settings-fragment.json`, `status: "active"`, `source_dir` pointing at this repo's own `.claude/extensions/email`, `installed_files` listing the copy targets), then run whatever install path the picker/`install-extension.sh` uses to actually copy files into `.claude/{agents,commands,skills,context,hooks}/` and merge `EXTENSION.md` into `.claude/CLAUDE.md`. Verification would have been: `bash .claude/scripts/check-extension-docs.sh` shows `[email] OK` with no WARN, and `grep -n "## Email Extension" .claude/CLAUDE.md` succeeds. **None of this should be performed**, per the intent finding above.

## Risks & Mitigations

- **Risk**: A future reviewer re-flags the same doc-lint WARN as a "gap" without checking cross-repo state. **Mitigation**: the completion summary and (optional) README.md scope-note addition in Recommendation 3 make the decision durably discoverable in-repo.
- **Risk**: `.dotfiles`'s cached extension manifest copy is stale (missing 3 keywords added by nvim tasks 815/816) relative to the nvim-repo source of truth. **Mitigation**: out of scope for task 819; flag as a candidate follow-up in `.dotfiles` (not this repo) if desired — not spawning a task here since it's cross-repo and this task's scope is this repo's `extensions.json` only.

## Context Extension Recommendations

- **Topic**: Cross-repo extension authoring/consumption pattern.
- **Gap**: `.claude/docs/architecture/extension-system.md` and `.claude/docs/guides/creating-extensions.md` describe `source_dir` and the picker mechanism only in the same-repo case; the cross-repo pattern (author in one repo, `source_dir` as an absolute path into a sibling repo, consume in another) is real and in production use (`email` in `.dotfiles`) but undocumented.
- **Recommendation**: Consider a short "Cross-Repo Extensions" subsection in `creating-extensions.md` describing this pattern, so future doc-lint/gap reviews (like the one that spawned task 819) check sibling repos before flagging a WARN as an actionable gap. (Not created as a task per this agent's instructions — recommendation only.)

## Appendix

- Commands run: `cat .claude/extensions.json`; `find .claude/extensions/email -type f`; reads of `manifest.json`/`EXTENSION.md`/`README.md`; `bash .claude/scripts/check-extension-docs.sh`; `sed -n` on `check-extension-docs.sh` policy comment/logic; `git log --oneline -- .claude/extensions/email`; `jq` queries against this repo's and `~/.dotfiles`' `state.json`/`extensions.json`; `diff -rq` of the two `extensions/email/` directories; `grep` of `~/.dotfiles/.claude/CLAUDE.md` for the Email Extension section; `grep` of `install-extension.sh` usage line.
- Key file paths referenced: `.claude/extensions.json`, `.claude/extensions/email/{manifest.json,EXTENSION.md,README.md}`, `.claude/scripts/check-extension-docs.sh` (lines ~154-260), `specs/reviews/review-2026-07-04.md` (line 128), `specs/state.json` (project 78, 819), `~/.dotfiles/.claude/extensions.json` (`extensions.email`), `~/.dotfiles/.claude/CLAUDE.md` (lines ~591+).
