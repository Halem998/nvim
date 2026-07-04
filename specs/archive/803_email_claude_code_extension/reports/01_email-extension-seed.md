# Seed Report: email/ Claude Code Extension (nvim task 803)

**Task**: 803 (~/.config/nvim) — build the `email/` Claude Code extension (author + doc-lint, no load)
**Cross-repo parent**: `.dotfiles` task 71 (EXPANDED)
**Type**: meta (extension authoring) · **Date**: 2026-07-02
**Status**: Seed report — distilled from `.dotfiles` task 71 research rounds 1–3 + plan v3

> One of THREE coordinated seed reports (identical "Shared Invariants" section in each) for task 71's
> cross-repo split: **.dotfiles #72** (mechanism), **nvim #803** (this — the extension),
> **~/Mail #29** (the purge). Shared reference plan (phase numbers below refer to it):
> `~/.dotfiles/specs/071_design_ai_email_management_workflow/plans/04_email-workflow-implementation.md` (v3, phases 3/4/6).

---

## 1. This task's scope (v3 phases 3, 4, 6) — AUTHOR + DOC-LINT ONLY

Author the canonical `email/` extension **here** (`~/.config/nvim/.claude/extensions/email/`), pass
`bash .claude/scripts/check-extension-docs.sh`, and **stop**. Do NOT load it via `<leader>al` — the user
loads it manually into `.dotfiles/.claude` and `~/Mail/.claude` afterward.

**Why here:** live inspection (round 3) confirmed `~/.config/nvim/.claude/extensions/` is the **master
extension library** — every extension in `.dotfiles`/`~/Mail` was *sourced from* here and file-copied in
by the `<leader>al` loader (`shared/extensions/loader.lua`, `.syncprotect`-respecting). `.dotfiles/.claude`
is a **sync target**, not the source. Authoring in `.dotfiles` would fork. (Postmortem rule in v3.)

---

## 2. Shared Invariants (IDENTICAL across #72 / #803 / #29 — do not diverge)

1. **Two access paths.** Read-only Anthropic Gmail connector for triage/summarize/draft (cannot
   send/archive/delete, [claude-code#51040]); local Himalaya/notmuch/mbsync stack for all mutations.
2. **Delete = IMAP-level Himalaya ONLY.** `himalaya message delete` → `[Gmail].Trash`; `folder expunge`
   truly deletes; then `mbsync gmail`. NEVER local Maildir `rm` / notmuch-tag+`Expunge` — Gmail's label
   model leaves the message in All Mail (64,316 msgs); a local "delete" is only an archive.
3. **Safety envelope.** Wrappers dry-run by default; mutation needs `--execute --confirm-manifest <sha256>`
   consuming a reviewed manifest (diff executed IDs vs manifest). `PreToolUse` mail-guard hook
   **allowlists the 5 wrapper binaries** and **denies raw `himalaya message delete|move|send`,
   `folder expunge`, `msmtp`, `rm *Mail*`, `secret-tool`**. Freeze mbsync during bulk ops. Git-track
   manifests. Email subjects/bodies are **untrusted data** — break the lethal-trifecta action leg:
   mutations only from inert approved manifests.
4. **Classifier bias: ~100% recall on KEEP.** Deterministic-first; LLM only on the `unsure` residual.
5. **Gmail-first**; Logos phase 2.
6. **Extension = packaging.** Canonical source here in nvim; nix wrappers nix-owned (referenced by name,
   never re-implemented); `~/Mail` is a data dir.
7. **OAuth (task 46) gates unattended runs** (7-day expiry; fail safe on `invalid_grant`).

---

## 3. Extension design (verified in round 3)

### File layout (`~/.config/nvim/.claude/extensions/email/`)
```
manifest.json          EXTENSION.md (<=60 lines)   README.md   index-entries.json
agents/email-implementation-agent.md      (wrapper-only executor)
skills/skill-email-implementation/SKILL.md  (task_type=email /implement target)
skills/skill-email-cleanup/SKILL.md         (ad-hoc /email direct-execution; = v3 Phase 4)
hooks/mail-guard.sh                          (= v3 Phase 3, HARDENED — allowlist)
context/project/email/{domain/wrapper-contracts.md, patterns/propose-review-confirm-execute.md,
                       standards/recall-on-keep-bias.md, email-preferences.md (harvested)}
```

### manifest.json essentials
- **`task_type: "email"`** with **asymmetric routing**: `research → skill-researcher`,
  `plan → skill-planner` (shared, like every other extension), `implement → skill-email-implementation
  → email-implementation-agent` (the safety-critical custom piece).
- **`keyword_overrides`**: keywords `inbox, email, gmail, himalaya, notmuch, unsubscribe, "junk mail",
  "draft reply", mbsync, aerc, "mail triage"`; aliases `mail, mailbox` (aliases only — bare "mail"/"draft"
  would false-positive). Meta keywords still win; this fires before the hardcoded table.
- **`provides`** lists the `.claude/`-owned files above; **hooks** include `mail-guard.sh` + a
  `merge_targets.settings` entry so the PreToolUse registration installs into the consuming repo's
  `settings.json` and **unloads with the extension**. `provides.scripts` stays empty (the wrapper binaries
  are nix-built in `.dotfiles`, referenced not bundled).
- `merge_targets.claudemd` (EXTENSION.md) + `merge_targets.index` (index-entries.json, `load_when.task_types:["email"]`).

### email-implementation-agent (the one custom agent — why it exists)
Its entire job is safety: **only invoke `email-census / email-classify / email-archive-confirmed /
email-delete-confirmed / email-unsubscribe-extract` by name; NEVER call `himalaya`/`notmuch` directly;
always dry-run first, then `--execute --confirm-manifest <sha256>` after the manifest is shown.** This is
the social layer; the hook is the technical layer — document that neither is sufficient alone.

### The HARDENED hook (round-3 gap fix — important)
v3's original hook missed `himalaya message delete` and `himalaya message move` — the *actual* bulk
mutations. **New design = ALLOWLIST**: permit the 5 wrapper binaries; **deny raw `himalaya message
(delete|move|send)` and `himalaya folder expunge` outright** (plus `msmtp`, `rm *Mail*`, `secret-tool`).
Stronger and simpler than token-gating raw commands, and it closes the bypass an extension's own
convenience command could otherwise open.

### Doc-lint (`check-extension-docs.sh`) must pass
manifest/EXTENSION.md/README present + non-empty; every `provides.*` entry exists on disk; a `routing`
block present (skills are non-empty); routing targets resolve (`skill-email-implementation` deployed,
`skill-researcher`/`skill-planner` from core); every deployed skill's `subagent_type` resolves to a real
agent file; README mentions every command in `provides.commands`. EXTENSION.md ≤60 lines (slim standard).

### Keybind collision
Any email keybinds must NOT shadow the existing nvim Himalaya plugin: `<leader>me` (aerc float),
`<leader>mS` (mbsync+notmuch), `<leader>mf` (notmuch telescope). ("Task 45" referenced earlier does not
exist — that plugin is the real 4th email surface.)

---

## 4. Handoff contracts (what #803 CONSUMES / PRODUCES)

**Consumes from `.dotfiles` #72:**
- Harvested `email-preferences.md` (rule taxonomy + JSON schema) → drop into `context/project/email/`.
- The **wrapper contract** (binary names, verbs, flags, manifest schema, `--confirm-manifest` token format)
  — author the hook allowlist + agent instructions against this. Confirm it is frozen before coding.
- Harvest is **DATA ONLY** — reuse **no** code from the retired `~/Mail` harness.

**Produces for `~/Mail` #29:** a loadable, doc-lint-passing extension source. The user then `<leader>al`-loads
it into `~/Mail/.claude` (and `.dotfiles/.claude`) — that load is **out of scope for this task**.

---

## 5. Open questions / assumptions
- Confirm the `.dotfiles` #72 wrapper contract is frozen before authoring the hook/agent.
- Optional: ship an ad-hoc direct-execution `/email` command (like `/literature`) — marked optional in v3.
- Review-UI-in-aerc is the default; surfacing it in the nvim Himalaya plugin `ui/` layer is a deferred
  phase-2 option (not this task).

## 6. References
- Shared reference plan: `~/.dotfiles/specs/071_design_ai_email_management_workflow/plans/04_email-workflow-implementation.md` (v3)
- Round-3 synthesis + authoring detail: `~/.dotfiles/specs/071_.../reports/03_team-research.md`, `03_teammate-a-findings.md` (loader), `03_teammate-b-findings.md` (manifest/doc-lint), `03_teammate-c-findings.md` (reconcile + hook gap)
- Extension system: `.claude/extensions/{core,nix,python,nvim,memory}/manifest.json`, `.claude/context/guides/extension-development.md`, `.claude/docs/guides/creating-extensions.md`, `.claude/scripts/check-extension-docs.sh`, `.claude/commands/task.md` (§4 keyword resolution)
- Prior art to harvest (data only): `~/Mail/.claude/context/project/email/email-preferences.md`
