# Research Report: Task #235

**Task**: 235 - Research and integrate MCP tools for founder extension
**Generated**: 2026-03-18
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Improve tooling that founder extension agents have access to
**Scope**: `.claude/extensions/founder/` - manifest.json, agent tool access
**Affected Components**: founder extension MCP configuration, agent tool lists
**Domain**: meta (system tooling)
**Language**: meta

## Task Requirements

Research and integrate MCP (Model Context Protocol) tools to enhance the founder extension's capabilities for:
1. Market research - tools for market data, industry reports, company information
2. Business strategy research - tools for competitive intelligence, trend analysis, financial data
3. Integration - update manifest.json mcp_servers, update agent allowed-tools

### Original Items (Consolidated)
1. Research MCP tools for market research
2. Research MCP tools for business strategy
3. Evaluate and integrate best tools into founder extension

## Current State Analysis

**Founder Extension v2.0**:
- 5 agents: market-agent, analyze-agent, strategy-agent, founder-plan-agent, founder-implement-agent
- Current MCP servers: `{}` (none configured)
- Agent tools: AskUserQuestion, Read, Write, Glob, Bash (file operations only)
- No web research tools (WebSearch, WebFetch) in agent tool lists
- Agents rely on user input via forcing questions for all data

**Gap Identified**:
- Agents cannot independently gather market data, company information, or industry trends
- All research depends on user providing data through forcing questions
- No integration with external data sources

## Integration Points

- **Component Type**: extension configuration (manifest.json, agent definitions)
- **Affected Area**: `.claude/extensions/founder/`
- **Action Type**: research + implement
- **Related Files**:
  - `.claude/extensions/founder/manifest.json` (mcp_servers field)
  - `.claude/extensions/founder/agents/market-agent.md` (Allowed Tools section)
  - `.claude/extensions/founder/agents/analyze-agent.md` (Allowed Tools section)
  - `.claude/extensions/founder/agents/strategy-agent.md` (Allowed Tools section)

## Research Areas

### MCP Tools for Market Research
- Company data APIs (Crunchbase, PitchBook equivalents)
- Industry report access (Gartner, CB Insights, Statista)
- Market sizing data sources
- SEC filings and financial data

### MCP Tools for Business Strategy
- Competitive intelligence tools
- Trend analysis and news aggregation
- Patent and IP databases
- Social listening and sentiment analysis

### Integration Considerations
- Tool authentication and API keys
- Rate limiting and cost considerations
- Tool reliability and data freshness
- Privacy and data handling

## Dependencies

None - this task can be started independently.

## Interview Context

### User-Provided Information
User wants systematic research into MCP and other tools for market research and business strategy, specifically for the founder extension agents.

### Effort Assessment
- **Estimated Effort**: 6-8 hours
- **Complexity Notes**: Research phase requires web search and evaluation; integration requires manifest.json and agent file updates

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 235 [focus]` with a specific focus prompt.*
