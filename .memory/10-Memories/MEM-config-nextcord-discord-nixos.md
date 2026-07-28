---
title: "Nextcord is the optimal Discord bot library on NixOS"
created: 2026-05-12
tags: [CONFIG]
topic: "configuration"
source: "specs/547_research_mobile_agent_management/reports/01_mobile-agent-management-research.md"
modified: 2026-05-12
retrieval_count: 0
last_retrieved: null
keywords: ["discord", "nextcord", "discordpy", "nixpkgs", "bot", "python"]
summary: "For Discord bot development on NixOS, nextcord (python3Packages.nextcord, v3.1.1) is the optimal choice"
token_count: 65
---

# Nextcord is the optimal Discord bot library on NixOS

For Discord bot development on NixOS, nextcord (python3Packages.nextcord, v3.1.1) is the optimal choice: actively maintained (Aug 2025), slash-command-native with decorator-based API, async/aiohttp-based, and available directly in nixpkgs without flake inputs. Prefer nextcord over discord.py for new projects due to more frequent updates and better Python 3.12+ support.

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
