# Research Report: Task #803 — Authoring Contract Verification

**Task**: `803 - Build email/ Claude Code extension (author + doc-lint, no load)`
**Started**: 2026-07-02T21:05:00Z
**Completed**: 2026-07-02T21:45:00Z
**Effort**: ~40 minutes (single-agent, codebase + cross-repo verification)
**Dependencies**: .dotfiles task 72 (VERIFIED COMPLETED — see Findings 6)
**Sources/Inputs**:
- `specs/803_email_claude_code_extension/reports/01_email-extension-seed.md` (prior art)
- `.claude/scripts/check-extension-docs.sh` (read in full, 445 lines; also executed)
- `.claude/extensions/nix/manifest.json`, `settings-fragment.json`, `index-entries.json`, `EXTENSION.md`, `skills/skill-nix-implementation/SKILL.md`, `agents/nix-implementation-agent.md`
- `.claude/extensions/{memory,literature,cslib,lean,founder}/manifest.json`, `.claude/extensions/founder/index-entries.json`
- `.claude/extensions/core/root-files/settings.json`, `.claude/commands/task.md`
- `lua/neotex/plugins/ai/shared/extensions/{loader.lua,merge.lua,init.lua}`, `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- `lua/neotex/plugins/tools/mail.lua`, `lua/neotex/plugins/editor/which-key.lua`, `lua/neotex/plugins/tools/himalaya/setup/wizard.lua`
- `.claude/docs/guides/creating-extensions.md`, `.claude/docs/reference/standards/extension-slim-standard.md`
- Cross-repo (readable, verified live): `~/.dotfiles/specs/state.json`, `~/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/handoffs/{wrapper-contract.md,email-preferences.md}`, `~/.dotfiles/specs/072_.../summaries/02_email-infra-wrappers-summary.md`, `~/.dotfiles/modules/home/email/agent-tools.nix`, `~/.dotfiles/.claude/hooks/mail-guard.sh`, `~/.dotfiles/.claude/settings.json`
**Artifacts**: `specs/803_email_claude_code_extension/reports/02_authoring-contract-verification.md` (this report)
**Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- The doc-lint contract is fully enumerated below from `.claude/scripts/check-extension-docs.sh`. Two seed-report claims are corrected: the script does NOT enforce the EXTENSION.md 60-line limit (that is a docs-only standard; nix's EXTENSION.md is 62 lines and passes lint), and `provides.hooks` entries are NOT existence-checked by lint (but ARE required on disk by the loader).
- Critical trap verified live: the lean extension currently FAILS doc-lint (exit 1) solely because it declares `routing_hard` targets that are not deployed — the exact failure mode the email extension would hit. Recommendation: omit `routing_hard` entirely. The lint baseline is therefore currently red repo-wide for a pre-existing, out-of-scope reason; acceptance should be `[email] PASS` in the per-extension table.
- The `.dotfiles` #72 dependency is CLOSED, not pending: task 72 is `completed` in `~/.dotfiles/specs/state.json`, the wrapper contract is FROZEN (with as-built addendum) at `~/.dotfiles/specs/072_.../handoffs/wrapper-contract.md`, all 5 wrapper binaries exist in `~/.dotfiles/modules/home/email/agent-tools.nix` (718 lines), the harvested 142-line `email-preferences.md` exists in `handoffs/`, and a working 97-line reference `mail-guard.sh` plus its `settings.json` registration already exist in `.dotfiles/.claude/`. Nothing needs to be stubbed.
- The `merge_targets.settings` mechanism is verified end-to-end in this repo's Lua: `settings-fragment.json` is deep-merged into `.claude/settings.local.json` with per-key tracking (`shared/extensions/merge.lua:229-257`) and cleanly unmerged on unload (`shared/extensions/init.lua:96,149`), so a fragment carrying a `hooks.PreToolUse` entry and `permissions.deny` array registers the mail-guard hook and unloads with the extension, as the task requires. `provides.hooks` files are copied to `.claude/hooks/` with exec permissions by `loader.lua:352-384`.
- The authoritative `keyword_overrides` schema is the nested cslib form `{"<task_type>": {"keywords": [...], "aliases": [...]}}` — this is the only form the `/task` step 4b/4e jq actually matches (`.claude/commands/task.md:123-190`); literature's flat form is dead config.
- Keybind collision is impossible by construction: the extension mechanism deploys only `.claude/` artifacts and merge targets, never Lua keybinds. The full currently-used `<leader>m*` set is enumerated in Findings 5 for any future UI surface; the seed's three bindings are confirmed but incomplete (which-key registers 15 more Himalaya bindings, including a pre-existing `<leader>mf`/`<leader>mS` double-claim between `mail.lua` and `which-key.lua`).

## Context & Scope

Report 01 (`reports/01_email-extension-seed.md`) distilled the cross-repo design from `.dotfiles` task 71. This report verifies its claims against the actual current state of this repo (the master extension library) and the now-readable sibling repos, and closes the seed's section-5 open questions. Scope of the parent task: author `.claude/extensions/email/` and pass `check-extension-docs.sh`; do not load. Verified: `.claude/extensions/email/` does not yet exist (confirmed by `ls`), and `specs/803_email_claude_code_extension/` currently contains only report 01.

## Findings

### 1. Doc-lint contract — exact checks in check-extension-docs.sh

All line references are to `.claude/scripts/check-extension-docs.sh` (read in full).

Required files (lines 402-404, via `check_file` at 45-57):
- `manifest.json`, `EXTENSION.md`, `README.md` — each must exist AND be non-empty.
- `manifest.json` must parse as valid JSON (`jq empty`, line 408).

`check_manifest_entries` (lines 59-107) — every declared entry must exist on disk:
- `provides.agents[]` → `agents/<name>` (file)
- `provides.skills[]` → `skills/<name>/SKILL.md`
- `provides.commands[]` → `commands/<name>` (file)
- `provides.rules[]` → `rules/<name>` (file)
- `provides.scripts[]` → `scripts/<name>` (file)
- NOT checked: `provides.hooks[]` and `provides.context[]` have no existence loop. Hooks files are nevertheless required at `hooks/<name>` by the loader (`loader.lua:361-372`), so author them anyway.

`check_routing_block` (lines 109-130): if `provides.skills` is non-empty and the manifest does not declare `routing_exempt: true` (literature does — `jq .routing_exempt` returns `true`), the manifest MUST have a `routing` key.

Rule A `check_undeclared_skills` (lines 133-148): every `skills/skill-*/` directory on disk MUST appear in `provides.skills` (reverse of the entries check).

Rules B+C `check_routing_consistency` (lines 165-264):
- "Installed" = any of the extension's source skills exists under `.claude/skills/` or any source agent under `.claude/agents/` (lines 172-196). The email extension will NOT be installed (author-only), so `installed=0`.
- `routing` targets (colon suffixes stripped, line 227): if not deployed under `.claude/skills/`, the target must be resolvable in SOME extension's `provides.skills` (Rule B, FAIL otherwise); if resolvable but extension uninstalled → WARN only (line 237). Consequence for email: `skill-email-implementation` and `skill-email-cleanup` resolve via email's own `provides.skills` → WARN, not FAIL. `skill-researcher` and `skill-planner` are deployed (verified: `.claude/skills/skill-researcher/`, `.claude/skills/skill-planner/` exist) → fast-path pass (line 203).
- `routing_hard` targets: FAIL when not deployed EVEN IF the extension is not installed (lines 256-261, "unconditional-dispatch FAIL clause"). Live proof: lean currently fails with exactly `FAIL: routing_hard target declared but not deployed (and extension not installed): skill-lean-research-hard` (and `-implementation-hard`) — the only failures in the whole run.

Rule D `check_deployed_skill_agents` (lines 267-289): applies ONLY to skills deployed under `.claude/skills/` (line 276 skips undeployed). Extracts the FIRST `subagent_type: "<name>"` match from SKILL.md; skips empty (direct-execution) and `"fork"`; otherwise `.claude/agents/<name>.md` must exist. For author-only email this check is skipped, but the SKILL.md must still be written so it passes after a future load: `skill-email-implementation/SKILL.md` should contain `subagent_type: "email-implementation-agent"` as its first such string (template: `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md:51` — `Use Agent tool with subagent_type: "nix-implementation-agent".`).

`check_readme_vs_manifest` (lines 291-317):
- WARN (non-fatal) if README.md mtime older than manifest.json.
- FAIL for every `provides.commands[]` entry `<c>.md` whose slash-form `/<c>` does not appear as a literal substring in README.md (line 312: `grep -q "/$cmd_name"`).

Rule E `check_referenced_scripts_declared` (lines 325-389): every `*.sh`/`*.sql` filename token mentioned in the extension's `commands/*.md`, `skills/*/SKILL.md`, `agents/*.md`, `README.md`, or `EXTENSION.md` (http URLs stripped first) must be covered by one of: own `provides.hooks`, own/any extension's `provides.scripts`, or core's `provides.scripts`/`provides.hooks`. Consequences for email: `mail-guard.sh` is covered by own `provides.hooks`; `check-extension-docs.sh` is in core's `provides.scripts` (verified via `jq` on `core/manifest.json`); the wrapper binaries (`email-census` etc.) have no `.sh` suffix and are exempt. Do NOT casually mention any other `.sh` filename in email docs.

NOT checked by lint (contrary to what a reader of seed §3 might infer): EXTENSION.md line count (the 60-line max lives only in `.claude/docs/reference/standards/extension-slim-standard.md:9`; nix's EXTENSION.md is 62 lines yet `[nix] PASS`), `index-entries.json` (never opened by the script), `merge_targets`, `keyword_overrides`, top-level `hooks`, `dependencies`.

Baseline state (script executed 2026-07-02): summary table shows all 18 extensions PASS except `lean FAIL`; overall exit code 1 (`FAIL: 2 issue(s) found`) — pre-existing and unrelated to email.

### 2. Template extensions — verified on-disk shapes

nix (`.claude/extensions/nix/manifest.json`, read in full) — closest structural template (custom implement skill + shared plan skill + agents + context + merge_targets.settings):
- Top-level keys: `name`, `version` ("1.0.0"), `description`, `task_type` ("nix"), `dependencies` (`["core"]`), `provides` (agents: 2 `.md` files; skills: 2 dirs; commands: `[]`; rules; context: `["project/nix"]`; scripts: `[]`; hooks: `[]`), `routing` (`research: {nix: skill-nix-research}`, `plan: {nix: skill-planner}` — shared planner, exactly the email pattern — `implement: {nix: skill-nix-implementation}`), `merge_targets` (`claudemd` {source: EXTENSION.md, target: .claude/CLAUDE.md, section_id: extension_nix}, `settings` {source: settings-fragment.json, target: .claude/settings.local.json}, `index` {source: index-entries.json, target: .claude/context/index.json}, `opencode_json`), `mcp_servers`, top-level `hooks` (lifecycle: preflight/context_injection scripts, run in-place, NOT copied — `.claude/docs/guides/creating-extensions.md:654-663`).
- `nix/settings-fragment.json`: keys `mcpServers`, `permissions.allow` — proves the fragment is an arbitrary settings subtree.
- `nix/index-entries.json`: `{"entries": [{path, description, load_when: {agents: [...], languages: [...]}, line_count, domain, subdomain, summary}]}`. For `load_when.task_types` (which the task mandates), the founder extension is the precedent: `founder/index-entries.json` entry for `project/founder/patterns/legal-planning.md` has `load_when: {agents: [...], languages: [...], task_types: ["contract-review","legal"], commands: []}`.
- Agent frontmatter (`nix/agents/nix-implementation-agent.md:1-5`): `name`, `description`, `model: sonnet`.
- Skill frontmatter (`nix/skills/skill-nix-implementation/SKILL.md:1-5`): `name`, `description`, `allowed-tools`.

memory (`.claude/extensions/memory/manifest.json`): template for shipping commands + a direct-execution skill — `provides.commands: ["learn.md","distill.md"]`, `provides.skills: ["skill-memory"]`, routing present, README mentions `/learn` and `/distill` (it passes lint). Model for the optional `commands/email.md` + `skill-email-cleanup` pair.

literature (`.claude/extensions/literature/manifest.json`): `routing_exempt: true` example (skills without routing); also carries the FLAT `keyword_overrides` form `{"literature": "meta", ...}` — see next finding for why email must not copy this.

### 3. keyword_overrides — authoritative schema and email manifest spec

`.claude/commands/task.md:123-190` is the only place keyword_overrides is consumed (no hits in `.claude/docs/` or `.claude/context/guides/`). Step 4b's jq is `.keyword_overrides // {} | to_entries[] | select(.value.keywords[]? as $kw | ($desc | test("\\b" + $kw + "\\b"))) | .key` and step 4e's alias remap is `select(.value.aliases[]? == $tt) | .key`. Both require the NESTED form keyed by task_type with `keywords`/`aliases` arrays (cslib's shape, verified: `cslib/manifest.json` has `{"cslib": {"keywords": [...], "aliases": ["lean4"]}}`). literature's flat `{"literature": "meta"}` yields `.value.keywords[]?` = null and never matches — dead config; do not imitate. Multi-word keywords ("junk mail", "draft reply", "mail triage") work because 4b uses regex `test()` against the whole lowercased description. Meta keywords win unconditionally at 4a, matching the task description's expectation. Alias remapping (4e) applies only to 4c/4d results, so `aliases: ["mail","mailbox"]` remaps the hardcoded-table/default outcomes without letting bare "mail" in a description trigger 4b directly — exactly the seed's stated intent.

Recommended email `manifest.json` (concrete, derived from nix + cslib + memory precedents):

```json
{
  "name": "email",
  "version": "1.0.0",
  "description": "AI email management: wrapper-only triage, classification, and confirmed-mutation workflow over Himalaya/notmuch via nix-built agent tools",
  "task_type": "email",
  "dependencies": ["core"],
  "keyword_overrides": {
    "email": {
      "keywords": ["inbox", "email", "gmail", "himalaya", "notmuch", "unsubscribe", "junk mail", "draft reply", "mbsync", "aerc", "mail triage"],
      "aliases": ["mail", "mailbox"]
    }
  },
  "provides": {
    "agents": ["email-implementation-agent.md"],
    "skills": ["skill-email-implementation", "skill-email-cleanup"],
    "commands": ["email.md"],
    "rules": [],
    "context": ["project/email"],
    "scripts": [],
    "hooks": ["mail-guard.sh"]
  },
  "routing": {
    "research":  { "email": "skill-researcher" },
    "plan":      { "email": "skill-planner" },
    "implement": { "email": "skill-email-implementation" }
  },
  "merge_targets": {
    "claudemd": { "source": "EXTENSION.md", "target": ".claude/CLAUDE.md", "section_id": "extension_email" },
    "settings": { "source": "settings-fragment.json", "target": ".claude/settings.local.json" },
    "index":    { "source": "index-entries.json", "target": ".claude/context/index.json" }
  }
}
```

Deliberate exclusions: NO `routing_hard` (Findings 1 — undeployed hard targets FAIL lint unconditionally; if hard-mode routing is wanted later, the only lint-safe author-time values are the deployed core hard skills `skill-researcher-hard`/`skill-planner-hard`/`skill-implementer-hard`, all verified present under `.claude/skills/`); NO `mcp_servers`; NO top-level lifecycle `hooks` (nothing to run at skill preflight); `provides.scripts` empty per the seed invariant (wrappers are nix-owned, referenced by name). `commands: ["email.md"]` is included per the Decisions section; drop it AND its README mention together if Q2 is decided the other way.

### 4. PreToolUse hook mechanism — verified wiring

Two independent mechanisms, both verified:

File deployment: `loader.lua` `M.copy_hooks` (`lua/neotex/plugins/ai/shared/extensions/loader.lua:352-384`) iterates `manifest.provides.hooks`, copies `hooks/<name>` from the extension source into the consuming repo's `.claude/hooks/<name>`, always preserving execute permissions. `hooks` is also in the loader's file-category list (line 694). So the canonical script lives at `.claude/extensions/email/hooks/mail-guard.sh`.

Registration + unload: `merge_targets.settings` deep-merges `settings-fragment.json` into `.claude/settings.local.json` (`shared/extensions/merge.lua:229-257` `merge_settings`: deep_merge with a `tracked` structure recording `new_object`/`new_array`/`new_value`/`appended` per key). Unload calls `unmerge_settings` (`shared/extensions/init.lua:149`; removal logic `merge.lua:263-289` removes appended array items by deep-equality). Full-sync re-injection is idempotent (`picker/operations/sync.lua:260-271`). Therefore a fragment like the following registers the hook AND unloads with the extension, satisfying the task requirement:

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash",
        "hooks": [ { "type": "command", "command": "bash .claude/hooks/mail-guard.sh 2>/dev/null || echo '{}'" } ] }
    ]
  },
  "permissions": {
    "deny": [
      "Bash(himalaya message delete*)", "Bash(himalaya message move*)", "Bash(himalaya * send*)",
      "Bash(himalaya folder expunge*)", "Bash(msmtp*)", "Bash(secret-tool*)", "Bash(rm *Mail*)"
    ]
  }
}
```

No existing extension ships hooks in a settings fragment (only `nix`, `lean`, `epidemiology` have fragments, all `mcpServers`/`permissions` — verified by key survey), so email is the first; the deep_merge/unmerge code paths handle nested objects and array appends generically, and this exact hooks+deny shape is already running live in `~/.dotfiles/.claude/settings.json` (matcher `"Bash"` entry invoking `bash .claude/hooks/mail-guard.sh`, plus those 7 deny entries appended after core's 4 — read directly from that file). Settings schema template in this repo: `.claude/extensions/core/root-files/settings.json:36-47` (PreToolUse, `matcher` regex string, `hooks[].type: "command"`). Note nix's fragment targets `.claude/settings.local.json` while core's hooks live in `settings.json`; Claude Code merges both, and following the nix precedent keeps the extension out of the core-owned file.

Hook script template: the AS-BUILT `~/.dotfiles/.claude/hooks/mail-guard.sh` (97 lines, task 72 Phase 7) is the reference implementation and was explicitly written to be copy-lifted by this task (its header: "nvim #803 packages this same allowlist/deny DATA for its consuming repos — the arrays below are kept isolated and copy-liftable"). Structure verified: `ALLOWED_BINARIES` array (the 5 wrappers), `DENY_PATTERNS` grep -E array (`himalaya message delete|move|send`, `himalaya template send`, `himalaya folder expunge`, `msmtp`, `secret-tool`, `rm .*Mail` — with chaining-safe anchors), stdin-JSON parsing of `.tool_input.command` with `CLAUDE_TOOL_INPUT` fallback, deny-before-allow precedence, `--confirm-manifest` hash capture into an audit log, `{"permissionDecision": "deny", ...}` / `{}` outputs. In-repo structural sibling: `.claude/extensions/core/hooks/validate-meta-write.sh` (same stdin pattern, per mail-guard's own comment).

### 5. Keybind collision — verified current <leader>m* map

Three sources register mail bindings in this config:

- `lua/neotex/plugins/tools/mail.lua` (header lines 13-15 + specs at 30, 58, 90): `<leader>me` (aerc float via toggleterm), `<leader>mS` (`mbsync -a` + `notmuch new`), `<leader>mf` (notmuch telescope search). This confirms the seed's three bindings.
- `lua/neotex/plugins/editor/which-key.lua:621-639` (MAIL GROUP): `<leader>m` (group "mail"), `mA` HimalayaAccounts, `mf` HimalayaFolder, `mF` HimalayaRecreateFolders, `mh` HimalayaHealth, `mi` HimalayaSyncInfo, `mm` HimalayaToggle, `ms` HimalayaSyncInbox, `mS` HimalayaSyncFull, `mr` maildir resync TermExec, `mt` HimalayaAutoSyncToggle, `mw` HimalayaWrite, `mW` HimalayaSetup, `mx` HimalayaCancelSync, `mX` HimalayaBackupAndFresh.
- `lua/neotex/plugins/tools/himalaya/setup/wizard.lua:288-290` (runtime, post-setup): `ml` Himalaya list, `ms` sync inbox, `mc` compose. Plus compose-mode buffer-local `me`/`md`/`mq` (`himalaya/commands/ui.lua:12`).

Also nearby: `<leader>ml`/`<leader>ms` are referenced by lectic (`lua/neotex/util/lectic_extras.lua:158-159`) in its own buffer context.

Conclusions: (a) the seed's claim holds but is incomplete — the reserved namespace is effectively ALL of `<leader>m[AefFhilmrsStwWxX]` plus the group key itself; (b) `mail.lua` and `which-key.lua` already double-claim `<leader>mf` and `<leader>mS` with different actions — a pre-existing config overlap, out of scope here but worth flagging; (c) most importantly, the extension deliverable ships NO Neovim keybinds — the loader copies only `.claude/` categories (agents, commands, rules, scripts, hooks, docs, templates, systemd — `loader.lua:694`) and merge targets. Collision is impossible by construction for this task; the constraint binds only a future task that adds an nvim UI surface (seed Q3, deferred).

### 6. Dependencies and handoff — #72 is complete; nothing needs stubbing

Verified directly in the sibling repo (readable from this environment, contrary to the task's caution):

- `~/.dotfiles/specs/state.json`: project 72 `email_workflow_infrastructure_prereqs` status `completed`; project 71 `expanded`.
- Wrapper contract FROZEN: `~/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/handoffs/wrapper-contract.md` (172 lines; titled "Wrapper Contract — FROZEN (Task 72, Phase 4)" with §10 "AS-BUILT ADDENDUM (Phases 5-11, 2026-07-02)"). Key contents for this task: §1 the five binaries with safety classes (`email-census` read-only; `email-classify` local-tags-only, `--append-approved`, `--limit <N>` default MAX_BATCH_SIZE; `email-unsubscribe-extract` read-only; `email-archive-confirmed` and `email-delete-confirmed` mutation, the latter with `--expunge-trash`); §2 global flags (dry-run by default; positive `--execute` requiring `--confirm-manifest <sha256>` over the raw manifest bytes; `--account gmail` reserved; `--manifest-dir`; `--help`); §5 constants (MAX_BATCH_SIZE=50, PLAN_EXPIRY_DAYS=7, delete auto-propose confidence >= 0.90, diff-against-manifest never re-derive); §8 two-layer enforcement; §9 explicitly scopes what #803 consumes and adds one NEW requirement not in the seed: the extension must include a $PATH precondition check that fails actionably when the wrapper binaries are not built.
- Binaries as-built: `~/.dotfiles/modules/home/email/agent-tools.nix` (718 lines) defines all five via `writeShellScriptBin` with `MAX_BATCH_SIZE=50` (line 34), `--execute`/`--confirm-manifest` parsing (lines 98-100), hash-mismatch refusal (line 129), batch enforcement (lines 235-240).
- Harvested preferences: `~/.dotfiles/specs/072_.../handoffs/email-preferences.md` (142 lines — the distilled harvest of the retired ~/Mail original, which is 746 lines at `~/Mail/.claude/context/project/email/email-preferences.md`; per the task, harvest DATA only, and the 142-line handoff version is the curated source to copy into `context/project/email/`).
- Reference hook + registration: `~/.dotfiles/.claude/hooks/mail-guard.sh` and the `"matcher": "Bash"` PreToolUse entry + 7 deny permissions in `~/.dotfiles/.claude/settings.json` (Findings 4).

Consequently the "authored now vs stubbed pending #72" split collapses: everything can be authored now against frozen, as-built interfaces. The only remaining external dependency is conventional, not technical: wrapper-contract.md §9 notes cross-repo ordering is documentation-only.

### 7. Additional verified details

- The five agent-callable names for the email-implementation-agent contract are exactly: `email-census`, `email-classify`, `email-archive-confirmed`, `email-delete-confirmed`, `email-unsubscribe-extract` (wrapper-contract.md §1; agent-tools.nix `writeShellScriptBin` lines 290, 328, 486, 548, 599).
- Deployed core skills the routing map relies on: `.claude/skills/skill-researcher/` and `.claude/skills/skill-planner/` exist (fast-path resolution in lint line 203).
- `EXTENSION.md` merge target uses `section_id` `extension_<name>` (nix: `extension_nix`); email should use `extension_email`. Content-wise, `.claude/CLAUDE.md` is regenerated from these sections, so EXTENSION.md is the extension's user-facing CLAUDE.md fragment (see nix EXTENSION.md structure: routing table, skill-agent mapping, key technologies).
- Lifecycle `hooks` (top-level manifest object) vs `provides.hooks` distinction is documented at `.claude/docs/guides/creating-extensions.md:654-663`: top-level = skill-lifecycle scripts run in place; `provides.hooks` = files copied to `.claude/hooks/`. Email needs only the latter.

## Decisions

- Use the nested cslib `keyword_overrides` schema; treat literature's flat form as a known-dead pattern (evidence: task.md 4b/4e jq shapes).
- Omit `routing_hard` from the email manifest (evidence: lean's live FAIL for undeployed routing_hard targets, lint lines 256-261).
- Ship `commands/email.md` + `skill-email-cleanup` (direct-execution, no `subagent_type` string in its SKILL.md so Rule D skips it even when deployed), and mention `/email` in README.md — resolving seed Q2 affirmatively (see Recommendations R4 for rationale).
- Source the hook from the as-built `.dotfiles` mail-guard.sh arrays rather than re-deriving patterns; the extension copy becomes canonical going forward (invariant 6: canonical source lives here).
- Copy the 142-line `handoffs/email-preferences.md` (the harvest) into `context/project/email/`, not the 746-line retired ~/Mail original.
- Interpret the acceptance criterion as `[email] PASS` in the doc-lint per-extension table, since the script's global exit code is currently 1 due to pre-existing lean failures.

## Recommendations

R1 (must, before writing files): Author to the PASS checklist derived from Findings 1 — (a) manifest.json/EXTENSION.md/README.md present and non-empty, manifest valid JSON; (b) every `provides.{agents,skills,commands,rules,scripts}` entry exists at its conventional path; (c) both skill dirs declared in `provides.skills` (Rule A); (d) `routing` block present with the asymmetric map from Findings 3; (e) no `routing_hard`; (f) README contains the literal string `/email` if `commands: ["email.md"]` is declared; (g) no undeclared `.sh` filename mentioned anywhere in email docs/skills/agents except `mail-guard.sh` (own hook) and core-declared scripts; (h) `hooks/mail-guard.sh` on disk and executable even though lint does not check it (the loader requires it).

R2 (must): Write `settings-fragment.json` exactly as in Findings 4 (hooks.PreToolUse Bash matcher + 7 permissions.deny entries) and declare `merge_targets.settings` so registration unloads with the extension; lift `ALLOWED_BINARIES`/`DENY_PATTERNS` verbatim from `~/.dotfiles/.claude/hooks/mail-guard.sh`.

R3 (must): In `email-implementation-agent.md` and `skill-email-implementation/SKILL.md`, encode the wrapper-only contract (five binaries by name, never raw `himalaya`/`notmuch`, dry-run first, `--execute --confirm-manifest <sha256>` only after manifest review) AND the §9 $PATH precondition check (`command -v email-census` fail-actionably pattern) — the latter is a requirement the seed missed. Put `subagent_type: "email-implementation-agent"` as the first such string in the SKILL.md.

R4 (should): Ship `/email` (commands/email.md + skill-email-cleanup) now rather than deferring: memory's `learn.md`/`skill-memory` gives the exact pattern, doc-lint cost is one README mention, and it completes v3 Phase 4 in the same authoring pass.

R5 (should): Keep EXTENSION.md at or under 60 lines per `extension-slim-standard.md` even though lint does not enforce it (nix at 62 shows drift is possible; do not add to it).

R6 (consider, separate task): The pre-existing lean `routing_hard` lint failures and the `mail.lua` vs `which-key.lua` `<leader>mf`/`<leader>mS` double-claim are both out of scope; flag them for follow-up tasks rather than fixing here.

## Risks & Mitigations

- Risk: A future `/task` description containing bare "mail"/"draft" false-positives into task_type email. Mitigation: verified schema places those only in `aliases` (4e remap), not `keywords` (4b), exactly as the seed intended; keep it that way.
- Risk: doc-lint global exit code stays 1 because of lean, making "pass check-extension-docs.sh" ambiguous. Mitigation: acceptance = `[email] PASS` row; optionally spawn a lean-fix task (R6).
- Risk: settings deep-merge appends the deny entries into a `permissions.deny` array that a consuming repo user later edits, weakening unmerge deep-equality matching. Mitigation: acceptable — unmerge failure leaves extra deny entries (fail-safe direction, more restrictive, never less).
- Risk: hook registered in `settings.local.json` may be gitignored in consuming repos, so the guard exists only per-machine. Mitigation: document in README that the technical layer (nix wrapper safety logic, agent-tools.nix) holds regardless (two-layer model, wrapper-contract.md §8); neither layer is sufficient alone.
- Risk: wrapper contract changes post-freeze. Mitigation: it is frozen with an as-built addendum and task 72 is completed; the extension references binaries by name only, so flag drift would surface as actionable wrapper errors, not silent misbehavior.

## Appendix

References read in this repo: `.claude/scripts/check-extension-docs.sh`; `.claude/extensions/nix/{manifest.json,settings-fragment.json,index-entries.json,EXTENSION.md,skills/skill-nix-implementation/SKILL.md,agents/nix-implementation-agent.md}`; `.claude/extensions/{memory,literature,cslib,lean,founder,core}/manifest.json`; `.claude/extensions/founder/index-entries.json`; `.claude/extensions/core/root-files/settings.json`; `.claude/extensions/core/hooks/validate-meta-write.sh` (by reference from mail-guard header); `.claude/commands/task.md`; `.claude/docs/guides/creating-extensions.md`; `.claude/docs/reference/standards/extension-slim-standard.md`; `lua/neotex/plugins/ai/shared/extensions/{loader.lua,merge.lua,init.lua}`; `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`; `lua/neotex/plugins/ai/claude/extensions/merge.lua`; `lua/neotex/plugins/tools/mail.lua`; `lua/neotex/plugins/editor/which-key.lua`; `lua/neotex/plugins/tools/himalaya/setup/wizard.lua`; `specs/803_email_claude_code_extension/reports/01_email-extension-seed.md`.

Cross-repo references verified live: `~/.dotfiles/specs/state.json`; `~/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/handoffs/{wrapper-contract.md,email-preferences.md,mail-29-runbook.md,oauth-gate.md,verification-baseline.md}`; `~/.dotfiles/specs/072_.../summaries/02_email-infra-wrappers-summary.md`; `~/.dotfiles/modules/home/email/agent-tools.nix`; `~/.dotfiles/.claude/hooks/mail-guard.sh`; `~/.dotfiles/.claude/settings.json`; `~/Mail/.claude/context/project/email/email-preferences.md` (size check only — retired original, data superseded by the 142-line handoff).

Commands executed: `bash .claude/scripts/check-extension-docs.sh` (baseline run, exit 1, lean-only failures); targeted `jq`/`grep` queries against the manifests, Lua modules, and sibling-repo state files cited above.
