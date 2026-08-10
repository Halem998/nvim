# Research Report: Task #78 (Re-Research)

**Task**: 78 - fix_himalaya_smtp_authentication_failure
**Started**: 2026-07-11T12:55:09-07:00
**Completed**: 2026-07-11T13:10:00-07:00
**Effort**: ~1 hour (live diagnostic re-verification)
**Dependencies**: None
**Sources/Inputs**: Live system inspection (himalaya config symlink, `~/.dotfiles/` flake, GNOME keyring via secret-tool, live SMTP AUTH test against smtp.gmail.com:465), Neovim himalaya plugin source, task 72 handoff docs in `~/.dotfiles/specs/`, prior report `reports/research-001.md`
**Artifacts**: /home/benjamin/.config/nvim/specs/078_fix_himalaya_smtp_authentication_failure/reports/02_himalaya-smtp-auth-recheck.md
**Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- **The February root cause (OAuth2 refresh-token expiry) is OBSOLETE.** Himalaya no longer uses
  OAuth2 at all: the gmail account now authenticates with `auth.type = "password"` using a Gmail
  **app password** read from the keyring
  (`secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com`).
- **Authentication currently SUCCEEDS.** A live `AUTH PLAIN` test against `smtp.gmail.com:465`
  with the stored app password returned `235 2.7.0 Accepted` (both with the password as stored,
  including spaces, and with spaces stripped). The 535 error described in the task does **not**
  reproduce at the credential/config level today.
- **The failure was fixed the same day it was researched.** The `gmail-app-password` keyring entry
  was created 2026-02-13 19:31 (hours after the Feb report), and the config was migrated to
  password auth. The task-72 handoff (`~/.dotfiles/specs/072_.../handoffs/oauth-gate.md`,
  2026-07-02) confirms himalaya send was verified **working** on the app-password path.
- **Config is now nix-managed.** `~/.config/himalaya/config.toml` is a home-manager symlink into
  the nix store. Its source of truth is `~/.dotfiles/config/himalaya-config.toml`, wired in
  `~/.dotfiles/modules/home/core/dotfiles.nix:38`. Deployed and source files are identical (no
  drift, generation 197, deployed 2026-07-08).
- **Recommended disposition**: verify one end-to-end send from `<leader>me`, then close task 78
  as resolved-by-prior-work; optionally spawn a small cleanup task for the dead OAuth2 remnants.

## Context & Scope

Re-investigation of the Gmail SMTP 535 5.7.8 failure on `<leader>me`, prompted by major changes
in both this repo and `~/.dotfiles/` since the February 2026 report. Scope: current effective
himalaya config, its home-manager provenance, credential/secret state, live auth verification,
and the current Neovim plugin send/OAuth code paths. Read-only research; no configs edited, no
emails sent.

## Findings

### 1. Current effective config (verified live)

`~/.config/himalaya/config.toml` is a symlink:

```
~/.config/himalaya/config.toml
  -> /nix/store/2z2zx7q0nd6qvakzy0gin1m9r6g3c5jy-home-manager-files/.config/himalaya/config.toml
  -> /nix/store/2jbcifs8yw5wf0c9mdj1q2wzyda578ff-hm_himalayaconfig.toml   (resolved)
```

Gmail account (resolved config):

```toml
[accounts.gmail]
email = "benbrastmckie@gmail.com"
backend.type = "maildir"
backend.root-dir = "/home/benjamin/Mail/Gmail"
message.send.backend.type = "smtp"
message.send.backend.host = "smtp.gmail.com"
message.send.backend.port = 465
message.send.backend.login = "benbrastmckie@gmail.com"
message.send.backend.encryption.type = "tls"
message.send.backend.auth.type = "password"
message.send.backend.auth.command = "secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com"
```

No OAuth2 anywhere in the config. A second account (`logos`) sends via Protonmail Bridge on
`127.0.0.1:1025`, also password auth.

### 2. Home-manager source of truth

- Source file: `~/.dotfiles/config/himalaya-config.toml`
- Wiring: `~/.dotfiles/modules/home/core/dotfiles.nix:38`:
  `".config/himalaya/config.toml".source = ../../../config/himalaya-config.toml;`
- `diff` of deployed nix-store file vs source: **identical** (no drift).
- Current home-manager generation: 197 (2026-07-08 23:34).
- Himalaya package: `~/.dotfiles/modules/home/packages/email-tools.nix` installs
  `pkgs-unstable.himalaya` (overridden); installed version is
  `himalaya v1.2.0 +smtp +oauth2 +sendmail +pgp-commands +wizard +imap +keyring +maildir`.

Any config-level change must be made in `~/.dotfiles/config/himalaya-config.toml` and applied
with a home-manager/nixos rebuild. The keyring **secret itself is imperative** (not nix-managed):
rotating the app password requires only `secret-tool store`, no rebuild.

### 3. Secret / OAuth2 provisioning state (verified live)

| Secret | Location | State |
|--------|----------|-------|
| Gmail app password | keyring `service=gmail-app-password username=benbrastmckie@gmail.com` | **PRESENT**, created 2026-02-13 19:31, 16-char Google app-password format (stored with spaces) |
| OAuth2 refresh token | keyring `service=himalaya-cli username=gmail-smtp-oauth2-refresh-token` | present but **dead** (known `invalid_grant`, no consumers) |
| OAuth2 access token | keyring `service=himalaya-cli username=gmail-smtp-oauth2-access-token` | present, stale, no consumers |
| OAuth2 client secret | keyring `service=himalaya-cli username=gmail-smtp-oauth2-client-secret` | present, no consumers |
| `GMAIL_CLIENT_ID` | env var + `~/.config/gmail-oauth2.env` | still set, unused by send path |

- `refresh-gmail-oauth2` still exists (`~/.nix-profile/bin/`, from
  `~/.dotfiles/modules/home/scripts/gmail-oauth2.nix`) but nothing invokes it: the systemd
  refresh service+timer were **deliberately disabled 2026-07-02** in
  `~/.dotfiles/modules/home/services/gmail-oauth2.nix` (task 72 Phase 3) because the refresh
  token is revoked (`invalid_grant`) and no component consumes OAuth2 tokens anymore.
- `mbsync` (IMAP sync) was likewise migrated to the same app password
  (`~/.dotfiles/modules/home/email/mbsync.nix`: `AuthMechs LOGIN` + `PassCmd secret-tool lookup
  service gmail-app-password ...`), per the user-confirmed decision (c) in
  `oauth-gate.md` — chosen to avoid Google's CASA Tier 2 verification required for restricted-
  scope OAuth in Production mode.

### 4. Live SMTP authentication test (decisive evidence)

Executed 2026-07-11 via `openssl s_client -connect smtp.gmail.com:465` with
`AUTH PLAIN base64("\0benbrastmckie@gmail.com\0<app-password>")`:

| Password form | Server response |
|---------------|-----------------|
| As stored in keyring (with spaces) | `235 2.7.0 Accepted` |
| Spaces stripped | `235 2.7.0 Accepted` |

**Conclusion**: the credential is valid right now, Gmail accepts it on port 465/TLS, and the
spaces in the stored secret are harmless (Gmail ignores them). There is no reproducible
credential/config failure.

### 5. Neovim plugin side (paths verified current)

The module layout cited in the Feb report still exists but behavior has changed:

- `lua/neotex/plugins/tools/himalaya/sync/oauth.lua` (524 lines) — `M.is_oauth_account()` now
  **parses the resolved config.toml** and returns `false` for gmail because it finds
  `auth.type = "password"` (lines 92-123). All OAuth refresh paths are therefore skipped for
  gmail.
- `lua/neotex/plugins/tools/himalaya/utils/cli.lua` (385 lines) — the auth-error handler
  (lines 135-175) only triggers an OAuth refresh when `account.oauth` is set AND
  `sync.auto_refresh_oauth` is true. `config/accounts.lua` defines no `oauth` field on the
  gmail account, so on an auth error the plugin reports it directly; no OAuth retry loop.
- Send path (`<leader>me`, documented in `config/ui.lua:631`):
  `ui/email_composer.lua` -> `data/scheduler.lua` (`M.send_email_now`, line 473) ->
  `utils.lua:M.send_email` (line 262), which runs
  `cat <tmp.eml> | himalaya message send -a gmail` via `vim.fn.system`. Himalaya itself
  resolves the password via the config's `auth.command` (secret-tool).
- The "persists through multiple retry attempts" symptom in the task description matches
  `scheduler.lua` config: `max_retries = 3`, `retry_backoff = 60`.
- Residual cruft: `config/oauth.lua` still carries gmail OAuth defaults
  (`refresh_command = "refresh-gmail-oauth2"`, `configure_command = "himalaya account configure
  gmail"`), and `sync.auto_refresh_oauth = true` remains the default in `config/init.lua:28`.
  Dead but harmless for the send path.

### 6. Root cause determination (current evidence)

- **Original failure (Feb 2026)**: occurred under the old OAuth2 config; root cause
  (Testing-mode 7-day refresh-token expiry -> `invalid_grant`) was plausibly correct **for that
  configuration**, and is corroborated by task 46/72 findings in `~/.dotfiles/specs/`.
- **Resolution already happened**: on 2026-02-13 the gmail app password was created in the
  keyring and himalaya was switched to password auth; by 2026-07-02 the task-72 verification
  recorded himalaya send as *working*; my live test on 2026-07-11 confirms auth succeeds.
- **Therefore task 78's described defect no longer exists.** No config regression from the nix
  migration was found (deployed == source, correct host/port/encryption/login, secret present
  and valid).
- **Only residual failure mode identified** (environmental, not currently reproducible):
  `auth.command` depends on `secret-tool`, which requires a D-Bus session with an unlocked
  GNOME keyring. If nvim/himalaya is launched from a bare TTY or SSH session without the
  keyring available, the lookup returns empty and Gmail would answer 535. Inside the normal
  graphical session (as tested) this is not an issue.

### 7. Stale claims in the February report (research-001.md)

| Feb claim | Current status |
|-----------|----------------|
| Root cause: expired OAuth2 refresh token | **Stale** — himalaya no longer uses OAuth2 at all |
| Fix: re-run `himalaya account configure gmail` | **Stale/wrong now** — the wizard would try to rewrite `config.toml`, which is a read-only nix-store symlink; also unnecessary for password auth |
| `~/.config/himalaya/config.toml` directly editable | **Stale** — it is a home-manager symlink; edits go in `~/.dotfiles/config/himalaya-config.toml` + rebuild |
| Tokens under `service=gmail-smtp-oauth2` | **Stale naming** — legacy tokens actually live under `service=himalaya-cli`; all are now unused |
| Plugin OAuth flow relevant to send failures | **Stale** — `oauth.lua` detects password auth and skips OAuth; `cli.lua` refresh gate is not satisfied for gmail |

## Recommendations

1. **Verify end-to-end, then close.** Send one test email to self via `<leader>me` (or
   `himalaya message send -a gmail` with a minimal RFC822 message on stdin). Given the live
   `235 Accepted` result, this is expected to pass; on success, mark task 78 resolved with a
   completion summary noting it was fixed by the Feb-13 app-password migration (dotfiles tasks
   46/72), not by any nvim change.
2. **If a 535 ever recurs**, follow the app-password runbook (see Appendix): check the keyring
   entry, run the live AUTH probe, and if Google revoked the app password (happens on Google
   password change / security events), mint a new one at
   `https://myaccount.google.com/apppasswords` and store it with
   `secret-tool store --label="gmail-app-password" service gmail-app-password username
   benbrastmckie@gmail.com`. **No nix rebuild required** — only the config layout is
   declarative; the secret is imperative.
3. **Config changes** (host/port/auth type) must be edited in
   `~/.dotfiles/config/himalaya-config.toml` and applied with
   `home-manager switch --flake ~/.dotfiles` (or the repo's `nixos-rebuild switch` wrapper if
   home-manager is a NixOS module).
4. **Optional cleanup task** (separate, low priority): remove dead OAuth2 remnants — legacy
   `service=himalaya-cli` keyring entries, `refresh-gmail-oauth2` script module,
   `~/.config/gmail-oauth2.env` / `GMAIL_CLIENT_ID` env wiring, and the plugin's gmail OAuth
   defaults in `config/oauth.lua` — to prevent future misdiagnosis. Keep the commented systemd
   block in `services/gmail-oauth2.nix` as the documented re-enable path if XOAUTH2 is ever
   wanted again.
5. **Do not** re-run `himalaya account configure gmail`; it is unnecessary for password auth
   and conflicts with the read-only nix-managed config.

## Decisions

- Treated the live SMTP AUTH probe as the decisive test for root-cause status (rather than
  sending a real email, which would have exceeded the read-only constraint).
- Classified the February OAuth2 analysis as historically correct but superseded, based on the
  documented, user-confirmed migration decision in `oauth-gate.md` (option (c), 2026-07-02).
- Did not modify any config, nix file, keyring entry, or task state (read-only research).

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| App password revoked by Google in future (password change/security event) | Medium over time | Runbook in Recommendations #2; secret rotation is keyring-only, no rebuild |
| `secret-tool` fails outside graphical session (locked/no keyring) -> empty password -> 535 | Low (GUI usage) | If sending from TTY/SSH, ensure `gnome-keyring-daemon` is running and unlocked; consider documenting in plugin health check (`<leader>mh`) |
| Plugin's dead OAuth defaults mislead future debugging | Medium | Cleanup task (Recommendations #4) |
| Consumer-Gmail app-password support withdrawn by Google (already removed for Workspace, May 2025) | Low/medium long-term | Fallback documented in `services/gmail-oauth2.nix` (re-enable XOAUTH2 + CASA path); revisit only if Google announces deprecation |
| Google rate-limits repeated failed logins during diagnostics | Low | Probe used at most 2 attempts; both succeeded |

## Context Extension Recommendations

- **Topic**: Nix/home-manager-managed tool configs (symlinked into nix store) and the
  declarative-config / imperative-secret split.
- **Gap**: No context file documents that several `~/.config/*` files in this environment are
  home-manager symlinks whose source of truth is `~/.dotfiles/config/` via
  `modules/home/core/dotfiles.nix`, and that keyring secrets are managed imperatively with
  `secret-tool`.
- **Recommendation**: Add a short section to `.claude/context/project/neovim/domain/` (or the
  nix extension context) covering "editing nix-managed configs" so future tasks do not attempt
  in-place edits of nix-store symlinks.

## Appendix

### A. Files examined (live, this session)

| File | Relevance |
|------|-----------|
| `~/.config/himalaya/config.toml` -> `/nix/store/2jbcifs8yw5wf0c9mdj1q2wzyda578ff-hm_himalayaconfig.toml` | Effective config; password auth confirmed |
| `~/.dotfiles/config/himalaya-config.toml` | Source of truth; identical to deployed |
| `~/.dotfiles/modules/home/core/dotfiles.nix:38` | Wiring of config.toml into home-manager |
| `~/.dotfiles/modules/home/packages/email-tools.nix` | Installs himalaya v1.2.0 (unstable, overridden) |
| `~/.dotfiles/modules/home/scripts/gmail-oauth2.nix` | Defines `refresh-gmail-oauth2` (legacy, unused) |
| `~/.dotfiles/modules/home/services/gmail-oauth2.nix` | OAuth refresh service/timer — commented out 2026-07-02 with full rationale |
| `~/.dotfiles/modules/home/email/mbsync.nix` | mbsync gmail store on `AuthMechs LOGIN` + app-password PassCmd |
| `~/.dotfiles/specs/072_email_workflow_infrastructure_prereqs/handoffs/oauth-gate.md` | Documents the OAuth->app-password decision and July-2 verified state |
| `lua/neotex/plugins/tools/himalaya/sync/oauth.lua` | Auth-type detection (password -> skip OAuth) |
| `lua/neotex/plugins/tools/himalaya/utils/cli.lua:135-175` | Auth-error handling; OAuth refresh gate not satisfied for gmail |
| `lua/neotex/plugins/tools/himalaya/utils.lua:262-306` | `M.send_email`: `cat tmp \| himalaya message send -a gmail` |
| `lua/neotex/plugins/tools/himalaya/data/scheduler.lua` | `max_retries = 3`, `retry_backoff = 60` (explains retry symptom) |
| `lua/neotex/plugins/tools/himalaya/config/{accounts,oauth,init,ui}.lua` | Plugin account/oauth defaults; `<leader>me` mapping doc |
| `specs/078_.../reports/research-001.md` | Prior report (Feb 2026), now partially stale |

### B. Diagnostic commands run (read-only)

```bash
readlink -f ~/.config/himalaya/config.toml
diff /nix/store/...-hm_himalayaconfig.toml ~/.dotfiles/config/himalaya-config.toml   # identical
secret-tool search --all service gmail-app-password                                  # present, 2026-02-13
secret-tool lookup service himalaya-cli username gmail-smtp-oauth2-refresh-token     # legacy, present/dead
himalaya --version                                                                   # v1.2.0
himalaya account list                                                                # gmail (Maildir, SMTP, default)
home-manager generations | head -3                                                   # gen 197, 2026-07-08

# Live SMTP AUTH probe (both password forms) — result: 235 2.7.0 Accepted
B64=$(printf '\0%s\0%s' "benbrastmckie@gmail.com" "$(secret-tool lookup service gmail-app-password username benbrastmckie@gmail.com)" | base64 -w0)
{ printf 'EHLO localhost\r\n'; sleep 1; printf 'AUTH PLAIN %s\r\n' "$B64"; sleep 3; printf 'QUIT\r\n'; } \
  | openssl s_client -connect smtp.gmail.com:465 -quiet
```

### C. What changed since the February report

1. **2026-02-13 19:31** — `gmail-app-password` keyring entry created; himalaya config switched
   from OAuth2 to password auth (same day as the original research).
2. **~Feb-Jul 2026** — `~/.dotfiles/` became a full NixOS + home-manager flake;
   `config.toml` became a nix-store symlink (declarative, read-only in place).
3. **2026-07-02 (task 72, Phase 3)** — OAuth2 refresh service/timer disabled with documented
   rationale; mbsync migrated to app password (user-confirmed decision (c)); himalaya send
   verified working on the app-password path; CASA Tier 2 identified as the (rejected) cost of
   keeping XOAUTH2.
4. **2026-07-08** — current home-manager generation 197 deployed; config unchanged and correct.
5. **2026-07-11 (this session)** — live SMTP auth verified succeeding; no reproducible defect.
