# Implementation Plan: Author the email/ Claude Code Extension

- **Task**: 803 - Build email/ Claude Code extension (author + doc-lint, no load)
- **Status**: [COMPLETED]
- **Effort**: 4.5 hours
- **Dependencies**: None (.dotfiles #72 VERIFIED COMPLETED -- wrapper contract frozen, all inputs available)
- **Research Inputs**: reports/01_email-extension-seed.md, reports/02_authoring-contract-verification.md
- **Artifacts**: plans/03_author-email-extension.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Author the canonical `email/` extension at `.claude/extensions/email/` in this repo (the master extension library) as a pure file-authoring task: manifest with asymmetric routing and nested `keyword_overrides`, a wrapper-only implementation agent, two skills plus a `/email` command, the hardened allowlist `mail-guard.sh` PreToolUse hook registered via `merge_targets.settings`, and harvested `context/project/email/` content. Definition of done: all deliverables exist on disk AND `bash .claude/scripts/check-extension-docs.sh` reports `[email] PASS` in its per-extension table (the repo-wide exit code remains 1 due to a pre-existing, out-of-scope lean `routing_hard` failure). The extension is NOT loaded via `<leader>al` -- authoring and doc-lint only.

### Research Integration

Report 02 is ground truth and corrects the seed in two places: doc-lint does NOT enforce the EXTENSION.md 60-line limit (docs-only standard, kept anyway per R5) and does NOT existence-check `provides.hooks` (the loader requires the file regardless, so it is authored and made executable). Verified constraints driving this plan: (a) OMIT `routing_hard` entirely -- undeployed `routing_hard` targets FAIL lint unconditionally (lean's live failure, lint lines 256-261); (b) use the NESTED cslib-style `keyword_overrides` schema -- the flat form is dead config (`task.md` 4b/4e jq); (c) `.dotfiles` #72 is COMPLETED, so the frozen wrapper contract, the 5 wrapper binaries, the copy-liftable 97-line `mail-guard.sh`, its settings registration, and the 142-line harvested `email-preferences.md` are AVAILABLE inputs; (d) contract §9 adds a requirement the seed missed: a `$PATH` precondition check (`command -v email-census` fail-actionably) in the agent/skill; (e) the concrete manifest.json and settings-fragment.json shapes are already spelled out in report 02 Findings 3-4 -- reuse them verbatim; (f) `merge_targets.settings` deep-merge/unmerge is verified end-to-end (`merge.lua:229-257`, `init.lua:96,149`), satisfying "the hook unloads with the extension"; (g) Rule E means no `.sh` filename other than `mail-guard.sh` (own hook) and core-declared scripts may be mentioned anywhere in email docs/skills/agents.

## Goals & Non-Goals

**Goals**:
- Author `.claude/extensions/email/` with every deliverable in the task description, matching report 02's verified manifest and settings-fragment shapes.
- Encode the WRAPPER-ONLY contract in the agent and implementation skill: only `email-census`, `email-classify`, `email-archive-confirmed`, `email-delete-confirmed`, `email-unsubscribe-extract` by name; NEVER raw `himalaya`/`notmuch`; dry-run first; `--execute --confirm-manifest <sha256>` only after manifest review; §9 `$PATH` precondition check.
- Ship the hardened ALLOWLIST `mail-guard.sh` (lift `ALLOWED_BINARIES`/`DENY_PATTERNS` arrays from the as-built `~/.dotfiles/.claude/hooks/mail-guard.sh`) plus `settings-fragment.json` (hooks.PreToolUse + 7 permissions.deny entries) declared under `merge_targets.settings` so registration unloads with the extension.
- Populate `context/project/email/` with harvested preferences (DATA only, from the 142-line #72 handoff), wrapper-contract summary, propose-review-confirm-execute pattern, and recall-on-keep-bias standard.
- Achieve `[email] PASS` from `check-extension-docs.sh`.

**Non-Goals**:
- Loading the extension via `<leader>al` into this or any consuming repo (user does this later; out of scope).
- Any code reuse from the retired `~/Mail` harness (harvest DATA only).
- Re-implementing or bundling the wrapper binaries (nix-owned in `.dotfiles`; referenced by name only; `provides.scripts` stays empty).
- Fixing the pre-existing lean `routing_hard` lint failure or the `mail.lua` vs `which-key.lua` `<leader>mf`/`<leader>mS` double-claim (flag for follow-up per R6, do not fix here).
- Any Neovim Lua/keybind surface (extension ships no Lua; collision impossible by construction -- verification checkbox only).
- `routing_hard`, `mcp_servers`, or top-level lifecycle `hooks` in the manifest (deliberate exclusions per report 02).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Sibling repos (`~/.dotfiles`, `~/Mail`) unreadable at implementation time | M | L | Report 02 captured all needed values (manifest shape, settings-fragment JSON, hook structure, 5 binary names, contract §§1/2/5/8/9, deny patterns); transcribe from report 02 if reads fail |
| `routing_hard` accidentally added (copying lean/cslib templates) | H | M | Explicit OMIT task in Phase 1; Testing checklist item asserts key absent (`jq '.routing_hard' == null`) |
| Flat `keyword_overrides` form used (copying literature) | M | L | Phase 1 task mandates nested cslib schema verbatim from report 02 Findings 3; lint does not catch this, so verify by jq in Phase 7 |
| Stray `.sh` filename mentioned in docs trips Rule E | M | M | Authoring rule in Phases 2-6: only `mail-guard.sh` and core-declared scripts (e.g. `check-extension-docs.sh`) may appear; Phase 7 lint run catches violations |
| README misses a `/email` mention while `commands: ["email.md"]` declared | M | L | Phase 2 task pairs the README `/email` mention with the manifest declaration; lint FAILs otherwise (line 312) |
| Repo-wide lint exit 1 (lean) misread as email failure | M | M | Acceptance criterion fixed as the `[email] PASS` row, not exit code; Phase 7 checks the per-extension table |
| `hooks/mail-guard.sh` forgotten or non-executable (lint does not check it) | H | L | Dedicated Phase 5 task + explicit `test -x` verification item (loader `loader.lua:352-384` requires it on load) |
| Bare "mail"/"draft" false-positive into task_type email | L | L | Keep "mail"/"mailbox" in `aliases` (4e remap) only, never `keywords` (4b), per verified schema semantics |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5, 6 | 1 |
| 3 | 7 | 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel. Note: doc-lint will FAIL for email between Phase 1 and the completion of wave 2 (declared `provides` entries not yet on disk) -- that is expected; only the Phase 7 run is the acceptance gate.

### Phase 1: Scaffold Directory and manifest.json [COMPLETED]

**Goal**: Create the extension skeleton and the manifest that declares everything the later phases must satisfy.

**Tasks**:
- [x] Create directory tree: `.claude/extensions/email/{agents,skills/skill-email-implementation,skills/skill-email-cleanup,commands,hooks,context/project/email/{domain,patterns,standards}}` *(completed)*
- [x] Write `.claude/extensions/email/manifest.json` using the report 02 Findings 3 JSON verbatim as the base: `name: "email"`, `version: "1.0.0"`, `task_type: "email"`, `dependencies: ["core"]`; NESTED `keyword_overrides` (`{"email": {"keywords": ["inbox","email","gmail","himalaya","notmuch","unsubscribe","junk mail","draft reply","mbsync","aerc","mail triage"], "aliases": ["mail","mailbox"]}}`); `provides` (agents: `["email-implementation-agent.md"]`, skills: `["skill-email-implementation","skill-email-cleanup"]`, commands: `["email.md"]`, rules: `[]`, context: `["project/email"]`, scripts: `[]`, hooks: `["mail-guard.sh"]`); asymmetric `routing` (`research -> skill-researcher`, `plan -> skill-planner`, `implement -> skill-email-implementation`); `merge_targets` (claudemd with `section_id: "extension_email"`, settings with `source: "settings-fragment.json"` / `target: ".claude/settings.local.json"`, index with `source: "index-entries.json"`) *(completed)*
- [x] Assert deliberate exclusions: NO `routing_hard`, NO `mcp_servers`, NO top-level lifecycle `hooks` key; validate with `jq empty` and `jq '.routing_hard'` returning `null` *(completed: verified null and valid JSON)*

**Timing**: 0.5 hours

**Depends on**: none

---

### Phase 2: index-entries.json, EXTENSION.md, README.md [COMPLETED]

**Goal**: Author the three merge-target/doc surfaces so lint's required-file and README-vs-manifest checks pass.

**Tasks**:
- [x] Write `.claude/extensions/email/index-entries.json` following the founder precedent (report 02 Findings 2): `{"entries": [...]}` with one entry per `context/project/email/` file (paths as deployed under `.claude/context/`), each with `description`, `load_when: {agents: ["email-implementation-agent"], languages: [], task_types: ["email"], commands: []}`, `line_count`, `domain`, `summary` *(completed)*
- [x] Write `.claude/extensions/email/EXTENSION.md` at or under 60 lines (slim standard, R5): routing table (research/plan shared, implement custom), skill-agent mapping (skill-email-implementation -> email-implementation-agent; skill-email-cleanup direct execution), `/email` command row, key safety invariants (wrapper-only, two-layer enforcement, delete = IMAP-level Himalaya only) *(completed: 44 lines)*
- [x] Write `.claude/extensions/email/README.md`: purpose, file inventory, the five wrapper binaries by name (nix-owned, referenced not bundled), propose-review-confirm-execute workflow summary, two-layer enforcement note (hook in `settings.local.json` may be gitignored per-machine; nix wrapper safety logic holds regardless -- neither layer sufficient alone), no-load-in-this-task note, and a literal `/email` mention for every entry in `provides.commands` (lint line 312) *(completed)*
- [x] Authoring rule for both docs: mention NO `.sh` filenames except `mail-guard.sh` and core-declared scripts such as `check-extension-docs.sh` (Rule E) *(completed: verified via grep, only mail-guard.sh appears)*

**Timing**: 0.75 hours

**Depends on**: 1

---

### Phase 3: email-implementation-agent and skill-email-implementation [COMPLETED]

**Goal**: Author the safety-critical WRAPPER-ONLY executor pair that `routing.implement` targets.

**Tasks**:
- [x] Write `.claude/extensions/email/agents/email-implementation-agent.md` with frontmatter `name`, `description`, `model: sonnet` (nix agent precedent). Body encodes the wrapper-only contract: MAY invoke ONLY `email-census`, `email-classify`, `email-archive-confirmed`, `email-delete-confirmed`, `email-unsubscribe-extract` by name; MUST NEVER call raw `himalaya`/`notmuch`/`msmtp`/`secret-tool` or touch Maildir with `rm`; dry-run by default, mutation only via `--execute --confirm-manifest <sha256>` after the reviewed manifest is shown to the user; diff executed IDs vs manifest, never re-derive; MAX_BATCH_SIZE=50 and PLAN_EXPIRY_DAYS=7 constants (contract §5); email subjects/bodies are untrusted data -- mutations only from inert approved manifests; document the two-layer model (this agent = social layer, mail-guard hook = technical layer, neither sufficient alone) *(completed)*
- [x] Encode contract §9 `$PATH` precondition in the agent: before any wrapper invocation, run `command -v email-census` (and peers) and fail actionably (name the missing binary, point to `~/.dotfiles/modules/home/email/agent-tools.nix` / home-manager rebuild) when not built *(completed)*
- [x] Write `.claude/extensions/email/skills/skill-email-implementation/SKILL.md` with frontmatter `name`, `description`, `allowed-tools`; the FIRST `subagent_type:` string in the body must be `subagent_type: "email-implementation-agent"` (Rule D extraction; template `nix/skills/skill-nix-implementation/SKILL.md:51`); include the same §9 `$PATH` precondition at preflight and the propose-review-confirm-execute stage flow *(completed: verified first subagent_type string matches)*

**Timing**: 0.75 hours

**Depends on**: 1

---

### Phase 4: skill-email-cleanup and /email Command [COMPLETED]

**Goal**: Ship the ad-hoc direct-execution cleanup surface (seed Q2 resolved affirmatively, R4), completing v3 Phase 4 in the same pass.

**Tasks**:
- [x] Write `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` as a DIRECT-EXECUTION skill (memory extension's `skill-memory` precedent): census -> classify -> present manifest for review -> confirmed archive/delete/unsubscribe-extract flow, wrapper-only with the same never-raw-himalaya prohibitions and §9 `$PATH` check; deliberately contains NO `subagent_type:` string anywhere so Rule D skips it even when deployed *(completed: verified no subagent_type string present)*
- [x] Write `.claude/extensions/email/commands/email.md` (memory's `learn.md` precedent) invoking skill-email-cleanup; confirm README.md's literal `/email` mention (Phase 2) covers this `provides.commands` entry *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

---

### Phase 5: Hardened mail-guard.sh and settings-fragment.json [COMPLETED]

**Goal**: Author the technical enforcement layer: the allowlist hook file plus the settings fragment that registers it and unloads with the extension.

**Tasks**:
- [x] Write `.claude/extensions/email/hooks/mail-guard.sh` by copy-lifting the as-built 97-line `~/.dotfiles/.claude/hooks/mail-guard.sh` (its header explicitly marks the arrays copy-liftable for this task; transcribe from report 02 Findings 4 if the sibling repo is unreadable): `ALLOWED_BINARIES` = the 5 wrappers; `DENY_PATTERNS` grep -E array covering `himalaya message delete|move|send`, `himalaya template send`, `himalaya folder expunge`, `msmtp`, `secret-tool`, `rm .*Mail` with chaining-safe anchors; stdin-JSON parse of `.tool_input.command` with `CLAUDE_TOOL_INPUT` fallback; deny-before-allow precedence; `--confirm-manifest` hash capture to audit log; `{"permissionDecision": "deny", ...}` / `{}` outputs. Set executable bit (`chmod +x`) -- lint does not check this file but `loader.lua:352-384` requires it *(completed: read the sibling repo directly, copy-lifted verbatim, chmod +x verified, bash -n syntax OK)*
- [x] Write `.claude/extensions/email/settings-fragment.json` exactly as report 02 Findings 4: `hooks.PreToolUse` with `matcher: "Bash"` invoking `bash .claude/hooks/mail-guard.sh 2>/dev/null || echo '{}'`, plus `permissions.deny` with the 7 entries (`Bash(himalaya message delete*)`, `Bash(himalaya message move*)`, `Bash(himalaya * send*)`, `Bash(himalaya folder expunge*)`, `Bash(msmtp*)`, `Bash(secret-tool*)`, `Bash(rm *Mail*)`); this fragment + the Phase 1 `merge_targets.settings` declaration is the verified registered-and-unloads-with-extension mechanism (`merge.lua:229-257`, `init.lua:149`) *(completed: jq empty passes, 7 deny entries confirmed)*

**Timing**: 0.5 hours

**Depends on**: 1

---

### Phase 6: context/project/email/ Content [COMPLETED]

**Goal**: Populate the extension's context payload -- harvested DATA plus the three doctrine files.

**Tasks**:
- [x] Copy the 142-line harvested `~/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/handoffs/email-preferences.md` to `.claude/extensions/email/context/project/email/email-preferences.md` (the curated harvest, NOT the 746-line retired `~/Mail` original; DATA only, no code reuse) *(completed: 142 lines, verbatim copy verified)*
- [x] Write `context/project/email/domain/wrapper-contracts.md`: the five binaries with safety classes (census read-only; classify local-tags-only with `--append-approved`/`--limit`; unsubscribe-extract read-only; archive-confirmed and delete-confirmed mutation, latter with `--expunge-trash`), global flags (dry-run default, `--execute --confirm-manifest <sha256>` over raw manifest bytes, `--account gmail`, `--manifest-dir`), constants (MAX_BATCH_SIZE=50, PLAN_EXPIRY_DAYS=7, delete auto-propose confidence >= 0.90), and the §9 `$PATH` precondition -- summarized from frozen wrapper-contract.md as captured in report 02 Findings 6 *(completed: 82 lines)*
- [x] Write `context/project/email/patterns/propose-review-confirm-execute.md`: manifest lifecycle (propose dry-run -> human review -> sha256 confirm -> execute -> diff executed IDs vs manifest), git-tracked manifests, freeze mbsync during bulk ops, untrusted-data/lethal-trifecta rationale *(completed: 50 lines)*
- [x] Write `context/project/email/standards/recall-on-keep-bias.md`: classifier bias standard (~100% recall on KEEP; deterministic-first, LLM only on the `unsure` residual; delete auto-propose only at confidence >= 0.90) *(completed: 42 lines)*
- [x] Confirm every file written here has a matching entry in Phase 2's `index-entries.json` (reconcile if paths changed) *(completed: line_count fields reconciled to actual wc -l for all 4 entries)*

**Timing**: 0.75 hours

**Depends on**: 1

---

### Phase 7: Doc-Lint Verification and Final Checks [COMPLETED]

**Goal**: Prove the definition of done: `[email] PASS` plus the manifest-hygiene and by-construction checks.

**Tasks**:
- [x] Run `bash .claude/scripts/check-extension-docs.sh`; acceptance = `[email] PASS` row in the per-extension summary table. Expected residuals: WARN (not FAIL) for `skill-email-implementation`/`skill-email-cleanup` routing targets resolving via email's own uninstalled `provides.skills` (lint line 237); repo-wide exit code 1 from the pre-existing lean `routing_hard` failure -- NOT an email failure *(completed: `[email]` block shows one WARN for skill-email-implementation and `OK`; summary table row is `email PASS`; repo-wide exit is FAIL: 2 issue(s) solely from lean)*
- [x] Run the manifest hygiene checks: `jq '.routing_hard' manifest.json` returns `null`; `jq '.keyword_overrides.email.keywords | length'` returns 11 and `.aliases` returns `["mail","mailbox"]` (nested schema); `test -x hooks/mail-guard.sh`; `jq empty settings-fragment.json` *(completed: all verified passing)*
- [x] Verification checkbox (no code): keybind collision impossible by construction -- the extension ships NO Lua and the loader copies only `.claude/` categories (`loader.lua:694`), so `<leader>me`/`<leader>mS`/`<leader>mf` (and the wider `<leader>m[AefFhilmrsStwWxX]` namespace) cannot be shadowed; record this in the implementation summary *(completed: confirmed, extension contains zero .lua files; recorded in summary)*
- [x] Flag (do not fix) the two out-of-scope findings for follow-up tasks per R6: lean `routing_hard` lint failure; `mail.lua` vs `which-key.lua` `<leader>mf`/`<leader>mS` double-claim *(completed: flagged in summary Follow-ups, not fixed)*
- [x] Confirm NO load was performed: `.claude/skills/skill-email-*` and `.claude/agents/email-implementation-agent.md` do NOT exist in this repo's deployed `.claude/` (author-only scope) *(completed: verified absent via ls)*

**Timing**: 0.75 hours

**Depends on**: 2, 3, 4, 5, 6

## Testing & Validation

Doc-lint PASS checklist (from report 02 Findings 1 / R1), plus hygiene checks:

- [x] `manifest.json`, `EXTENSION.md`, `README.md` present and non-empty; `manifest.json` parses (`jq empty`)
- [x] Every `provides.agents[]` entry exists: `agents/email-implementation-agent.md`
- [x] Every `provides.skills[]` entry exists: `skills/skill-email-implementation/SKILL.md`, `skills/skill-email-cleanup/SKILL.md`
- [x] Every `provides.commands[]` entry exists: `commands/email.md`
- [x] `provides.rules` and `provides.scripts` are empty (nothing to check; wrappers are nix-owned, referenced by name)
- [x] Rule A: both on-disk `skills/skill-*/` directories are declared in `provides.skills` (no undeclared skills)
- [x] `routing` block present (skills non-empty, no `routing_exempt`); targets resolve: `skill-researcher`/`skill-planner` deployed under `.claude/skills/` (fast-path), `skill-email-implementation` resolves via own `provides.skills` (WARN-only while uninstalled)
- [x] `routing_hard` key ABSENT from manifest (`jq '.routing_hard'` = `null`) -- the live lean-failure trap
- [x] README.md contains the literal string `/email` (one per `provides.commands` entry)
- [x] Rule E: no `.sh`/`.sql` filename appears in email commands/skills/agents/README/EXTENSION.md except `mail-guard.sh` (own `provides.hooks`) and core-declared scripts; wrapper binaries are suffix-free and exempt
- [x] `hooks/mail-guard.sh` exists AND is executable (loader requirement; NOT lint-checked -- verify manually)
- [x] `settings-fragment.json` valid JSON with `hooks.PreToolUse` Bash matcher + 7 `permissions.deny` entries; `merge_targets.settings` declared in manifest
- [x] `keyword_overrides` uses the nested cslib schema; "mail"/"mailbox" appear ONLY in `aliases`
- [x] `index-entries.json` entries use `load_when.task_types: ["email"]` (founder precedent; not lint-checked)
- [x] EXTENSION.md at or under 60 lines (slim standard; not lint-enforced -- do not drift like nix's 62) *(44 lines)*
- [x] `skill-email-implementation/SKILL.md` first `subagent_type:` string is `"email-implementation-agent"`; `skill-email-cleanup/SKILL.md` contains no `subagent_type:` string
- [x] Agent and implementation skill both encode the §9 `$PATH` precondition check
- [x] Keybind collision checkbox: extension ships no Lua; `<leader>me`/`<leader>mS`/`<leader>mf` untouched by construction
- [x] Final: `check-extension-docs.sh` per-extension table shows `[email] PASS` (repo-wide exit 1 from lean is acceptable and out of scope)

## Artifacts & Outputs

All paths relative to `/home/benjamin/.config/nvim/`:

- `.claude/extensions/email/manifest.json` -- task_type=email, nested keyword_overrides, asymmetric routing, merge_targets (claudemd/settings/index), NO routing_hard
- `.claude/extensions/email/EXTENSION.md` -- slim (<=60 lines) CLAUDE.md fragment, section_id `extension_email`
- `.claude/extensions/email/README.md` -- full doc; mentions `/email`; two-layer enforcement note
- `.claude/extensions/email/index-entries.json` -- context index entries, `load_when.task_types: ["email"]`
- `.claude/extensions/email/settings-fragment.json` -- PreToolUse hook registration + 7 deny permissions (unloads with extension)
- `.claude/extensions/email/agents/email-implementation-agent.md` -- WRAPPER-ONLY executor, §9 $PATH check
- `.claude/extensions/email/skills/skill-email-implementation/SKILL.md` -- /implement target, subagent_type email-implementation-agent
- `.claude/extensions/email/skills/skill-email-cleanup/SKILL.md` -- direct-execution ad-hoc cleanup (no subagent_type)
- `.claude/extensions/email/commands/email.md` -- /email command invoking skill-email-cleanup
- `.claude/extensions/email/hooks/mail-guard.sh` -- hardened allowlist hook (executable), copy-lifted from as-built .dotfiles version
- `.claude/extensions/email/context/project/email/email-preferences.md` -- 142-line harvested prefs (DATA only)
- `.claude/extensions/email/context/project/email/domain/wrapper-contracts.md` -- frozen contract summary
- `.claude/extensions/email/context/project/email/patterns/propose-review-confirm-execute.md` -- manifest lifecycle pattern
- `.claude/extensions/email/context/project/email/standards/recall-on-keep-bias.md` -- classifier bias standard
- `specs/803_email_claude_code_extension/summaries/03_author-email-extension-summary.md` -- implementation summary (written by /implement)

## Rollback/Contingency

The extension is a single new directory with no deployed footprint (author-only; nothing copied into `.claude/skills/`, `.claude/agents/`, `.claude/hooks/`, or any settings file in this or any consuming repo). Rollback = `git rm -r .claude/extensions/email/` (or `rm -rf` if uncommitted) with zero side effects; no unmerge needed because `merge_targets` only takes effect at load time, which this task never performs. If doc-lint cannot reach `[email] PASS` after remediation attempts, keep the directory, mark the failing phase [BLOCKED] with the exact FAIL lines from the lint output, and leave the task in [IMPLEMENTING] for a follow-up dispatch; partial authored files are safe to keep on disk since nothing consumes them until a deliberate `<leader>al` load.
