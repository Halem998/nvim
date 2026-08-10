# Implementation Report: LINK_API_TOKEN sops-nix Setup

**Task**: 571 - Discord + OpenCode + Neovim integration
**Date**: 2026-05-14
**Scope**: Wire `link_api_token` through sops-nix and inject into both the discord-bot service and the Neovim shell environment

---

## Problem

The `<leader>ar` keybinding in Neovim (`discord-link.lua`) requires `DISCORD_BOT_LINK_TOKEN` to be set in the environment. It was not set, causing the error:

```
DISCORD_BOT_LINK_TOKEN not set -- check env
```

On the bot side, `LINK_API_TOKEN` was configured as an empty plain-text environment variable in the systemd service, meaning the HTTP API had no authentication at all.

## Root Cause

`link_api_token` existed in `secrets/secrets.yaml` but was set to an empty string and was **not** wired through the sops-nix pipeline — it was neither declared in `sops.secrets`, nor injected via `LoadCredential`, nor read from `/run/secrets/`. The discord-bot service just set `LINK_API_TOKEN=` directly.

## Changes Made

All changes in `/home/benjamin/.dotfiles/configuration.nix`:

### 1. Declared `link_api_token` as a sops secret

Added to the `sops.secrets` block alongside the existing secrets:

```nix
"link_api_token" = {
  owner = config.users.users.benjamin.name;
};
```

This causes sops-nix to decrypt the value to `/run/secrets/link_api_token` at activation time.

### 2. Injected token into discord-bot service via LoadCredential

Added to the `LoadCredential` array:

```nix
"link_api_token:${config.sops.secrets."link_api_token".path}"
```

Changed the environment variable from a plain empty string to the credential file reference:

```nix
# Before:
"LINK_API_TOKEN="

# After:
"LINK_API_TOKEN=%d/link_api_token"
```

The bot's `auth.py` now validates Bearer tokens against this value instead of skipping auth.

### 3. Set `DISCORD_BOT_LINK_TOKEN` for Neovim via fish shell init

Added to `programs.fish.interactiveShellInit`:

```fish
if test -r /run/secrets/link_api_token
  set -gx DISCORD_BOT_LINK_TOKEN (cat /run/secrets/link_api_token)
end
```

Both sides now read the same secret from the sops-nix pipeline — no plaintext tokens in any committed file.

## Prerequisite (completed by user)

The user generated a real token and encrypted it into `secrets/secrets.yaml`:

```bash
openssl rand -hex 32
sops secrets/secrets.yaml
# Set link_api_token to the generated value
```

## Applying

```bash
sudo nixos-rebuild switch --flake .#hamsa
```

## Verification

```bash
# Token is available in new shells
echo $DISCORD_BOT_LINK_TOKEN

# Bot API responds with authentication
curl -s -H "Authorization: Bearer $DISCORD_BOT_LINK_TOKEN" http://localhost:8080/health | jq .

# Neovim linking works
# Open Neovim with an OpenCode session, press <leader>ar
```

## Security Model

```
secrets.yaml (encrypted, committed)
  → sops-nix decrypts at nixos-rebuild activation
    → /run/secrets/link_api_token (tmpfs, RAM-only, owner: benjamin)
      → discord-bot.service reads via LoadCredential (%d/link_api_token)
      → fish shell reads at login, sets DISCORD_BOT_LINK_TOKEN
        → Neovim inherits env, sends as Bearer token in HTTP requests
```

No plaintext token in any committed file. The token only exists in RAM (tmpfs) and in the encrypted secrets.yaml.
