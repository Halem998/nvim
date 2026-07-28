---
title: "OpenCode headless/CLI API for programmatic agent control"
created: 2026-05-12
tags: [INSIGHT]
topic: "insight"
source: "specs/547_research_mobile_agent_management/reports/01_mobile-agent-management-research.md"
modified: 2026-05-12
retrieval_count: 0
last_retrieved: null
keywords: ["opencode", "headless", "server", "CLI", "session-management", "programmatic-access"]
summary: "OpenCode has a comprehensive headless/CLI API: 'opencode serve' starts a persistent server"
token_count: 91
---

# OpenCode headless/CLI API for programmatic agent control

OpenCode has a comprehensive headless/CLI API: 'opencode serve' starts a persistent server with basic auth (OPENCODE_SERVER_PASSWORD), 'opencode run --command' executes named commands programmatically, 'opencode attach' connects to remote servers, and 'opencode session list/delete' manages session lifecycle. The --format json flag enables machine-parseable output. This client-server architecture means OpenCode agents can be controlled from external services like Discord bots or webhooks without the Neovim TUI.

## Connections
<!-- Add links to related memories using [[filename]] syntax -->
