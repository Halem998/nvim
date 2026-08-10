# Research Report: Task #235

**Task**: 235 - research_integrate_mcp_founder
**Started**: 2026-03-18T12:00:00Z
**Completed**: 2026-03-18T12:45:00Z
**Effort**: 2-3 hours (research) + 4-6 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: WebSearch, WebFetch, Codebase (founder extension agents)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Identified 25+ MCP servers relevant to founder/startup use cases across 6 categories
- Recommended 8 high-priority MCP servers for immediate integration based on agent needs
- Found most relevant servers have free tiers suitable for development/testing
- Integration approach: Add to manifest.json `mcp_servers` field and agent `allowed-tools`

## Context & Scope

The founder extension (`.claude/extensions/founder/`) has 5 agents:
- **market-agent**: TAM/SAM/SOM analysis, market sizing
- **analyze-agent**: Competitive landscape, positioning maps, battle cards
- **strategy-agent**: GTM strategy, positioning, channel analysis, 90-day plans
- **founder-plan-agent**: Implementation planning for founder tasks
- **founder-implement-agent**: Execution of founder-related implementations

Currently, these agents only have access to basic file operations (Read, Write, Glob, Bash) and AskUserQuestion for interactive forcing questions. They lack the ability to:
1. Search the web for market data
2. Access company/competitor information
3. Pull financial data
4. Scrape competitor websites
5. Access productivity/CRM tools

## Findings

### Category 1: Financial & Market Data MCP Servers

| Server | Description | Auth | Free Tier | Relevance |
|--------|-------------|------|-----------|-----------|
| **Alpha Vantage** | Real-time & historical stock, ETF, options, forex, crypto, fundamentals | API Key | Yes (5 calls/min, 500/day) | HIGH - Market sizing, industry trends |
| **Financial Datasets** | Income statements, balance sheets, cash flows, stock prices | API Key | Yes (limited) | HIGH - Company financials for competitive analysis |
| **SEC EDGAR** | 13M+ SEC filings, XBRL financials, 10-K/10-Q/8-K | None | Yes (free) | HIGH - Public company research, competitor financials |
| **EODHD** | Historical financial data, fundamentals | API Key | Yes (limited) | MEDIUM - Backup financial data source |
| **Crunchbase** | Startup funding, investment data, company profiles | API Key | Yes (5K req/mo) | HIGH - Competitor funding, startup ecosystem |

**Recommendation**: Integrate Alpha Vantage, SEC EDGAR, and Crunchbase as primary financial data sources.

### Category 2: Competitive Intelligence MCP Servers

| Server | Description | Auth | Free Tier | Relevance |
|--------|-------------|------|-----------|-----------|
| **Ezbiz Business Intelligence** | Competitor analysis, web presence scoring, review analysis | API Key | Unknown | HIGH - Direct competitive intelligence |
| **CB Insights** | Market intelligence, funding data, competitive analysis | API Key | No (enterprise) | HIGH - Premium competitive data |
| **PredictLeads** | Company signals: funding, hiring, tech adoption | API Key | Yes (limited) | HIGH - Competitor activity tracking |
| **Semrush** | SEO analytics, traffic data, keyword research | API Key | Yes (limited) | MEDIUM - Digital competitive analysis |
| **SimilarWeb** | Web analytics, traffic data, competitive metrics | API Key | Yes (limited) | MEDIUM - Website traffic analysis |

**Recommendation**: Integrate Ezbiz Business Intelligence and PredictLeads for competitive intelligence. Crunchbase (from Category 1) also serves this purpose.

### Category 3: Web Search & Research MCP Servers

| Server | Description | Auth | Free Tier | Relevance |
|--------|-------------|------|-----------|-----------|
| **Brave Search** | Privacy-focused web search with 6 tools | API Key | Yes (1 req/sec) | HIGH - General market research |
| **Tavily** | AI-optimized search with citations | API Key | Yes (1K searches/mo) | HIGH - Factual research with sources |
| **Perplexity** | Answer-focused search with citations | API Key | Yes (limited) | MEDIUM - Quick answers |
| **Exa** | AI-native search engine | API Key | Yes (limited) | MEDIUM - AI-optimized results |
| **mcp-omnisearch** | Unified multi-provider search (Tavily, Brave, Perplexity, Kagi) | Multiple | Varies | HIGH - Single interface, multiple backends |

**Recommendation**: Integrate Brave Search as primary (best free tier, most features) and Tavily as backup (optimized for AI agents).

### Category 4: Web Scraping & Data Extraction

| Server | Description | Auth | Free Tier | Relevance |
|--------|-------------|------|-----------|-----------|
| **Firecrawl** | Web scraping with LLM-optimized output | API Key | Yes (500 credits/mo) | HIGH - Competitor website analysis |
| **Bright Data** | Enterprise scraping, CAPTCHA solving, proxy rotation | API Key | Yes (5K req/mo) | MEDIUM - Heavy-duty scraping |
| **Browserbase** | Cloud browser automation | API Key | Yes (limited) | MEDIUM - Complex interactions |
| **Apify** | 3,000+ pre-built scrapers | API Key | Yes ($5 free credit) | HIGH - Ready-made extractors |
| **Crawlbase** | HTML/markdown/screenshot extraction | API Key | Yes (limited) | LOW - Basic scraping |

**Recommendation**: Integrate Firecrawl (best for competitor analysis) and Apify (pre-built actors for common sources).

### Category 5: Productivity & CRM MCP Servers

| Server | Description | Auth | Free Tier | Relevance |
|--------|-------------|------|-----------|-----------|
| **Notion** | Official Notion MCP for workspace access | OAuth | Yes (with Notion account) | MEDIUM - Strategy documentation |
| **Google Sheets** | Spreadsheet read/write/search | OAuth | Yes (with Google account) | HIGH - Data collection, analysis |
| **HubSpot** | CRM data access (contacts, companies, deals) | OAuth | Yes (with HubSpot account) | MEDIUM - Customer/prospect data |
| **LinkedIn** | Profile/company scraping, job search | API Key | Varies | HIGH - Competitive hiring, company research |
| **GitHub** | Repository analysis, code search | API Token | Yes | LOW - Tech stack analysis |

**Recommendation**: Integrate Google Sheets (data collection) and LinkedIn (company research). Notion optional for documentation.

### Category 6: Aggregators & Meta-Servers

| Server | Description | Auth | Free Tier | Relevance |
|--------|-------------|------|-----------|-----------|
| **Pipedream** | 2,500+ API connections | API Key | Yes (limited) | HIGH - Universal connector |
| **MindsDB** | Unified data middleware | Varies | Yes | MEDIUM - Data unification |
| **AnyQuery** | SQL queries across 40+ apps | Varies | Yes | MEDIUM - Cross-app queries |
| **Composio** | MCP orchestration platform | API Key | Yes | HIGH - Tool aggregation |

**Recommendation**: Consider Pipedream for connecting to APIs without dedicated MCP servers.

## Recommendations

### Priority 1: Immediate Integration (High Impact, Low Effort)

These servers are well-maintained, have good free tiers, and directly address agent needs:

1. **Brave Search** - General market research for all agents
   - Use case: Market sizing research, competitor discovery
   - Free tier: 1 req/sec, generous limits
   - Integration: Add to market-agent, analyze-agent, strategy-agent

2. **Crunchbase** - Startup/company intelligence
   - Use case: Competitor funding, company profiles, market landscape
   - Free tier: 5,000 req/month
   - Integration: Add to market-agent, analyze-agent

3. **SEC EDGAR** - Public company financials
   - Use case: Competitor financial statements, industry analysis
   - Free tier: Unlimited (rate limited)
   - Integration: Add to market-agent, analyze-agent

4. **Firecrawl** - Web scraping for competitor analysis
   - Use case: Scrape competitor websites, pricing pages, feature lists
   - Free tier: 500 credits/month
   - Integration: Add to analyze-agent

### Priority 2: Secondary Integration (High Impact, More Setup)

5. **LinkedIn** - Company and talent research
   - Use case: Competitor hiring patterns, company size, leadership
   - Auth: Requires LinkedIn account/API access
   - Integration: Add to analyze-agent, strategy-agent

6. **Google Sheets** - Data collection and analysis
   - Use case: Store market research, track competitors, share findings
   - Auth: OAuth with Google
   - Integration: Add to all founder agents

7. **Alpha Vantage** - Financial market data
   - Use case: Industry trends, public company metrics
   - Free tier: 5 API calls/minute, 500/day
   - Integration: Add to market-agent

### Priority 3: Optional/Future Integration

8. **Tavily** - Backup search with AI optimization
9. **Apify** - Pre-built scrapers for specific sources
10. **PredictLeads** - Company activity signals
11. **Semrush** - SEO/traffic analysis
12. **HubSpot** - CRM integration (if user has HubSpot)

## Integration Architecture

### manifest.json Changes

```json
{
  "mcp_servers": {
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-server-brave-search"],
      "env": {
        "BRAVE_API_KEY": "${BRAVE_API_KEY}"
      }
    },
    "crunchbase": {
      "command": "npx",
      "args": ["-y", "@cyreslab/crunchbase-mcp-server"],
      "env": {
        "CRUNCHBASE_API_KEY": "${CRUNCHBASE_API_KEY}"
      }
    },
    "sec-edgar": {
      "command": "npx",
      "args": ["-y", "@stefanoamorelli/sec-edgar-mcp"],
      "env": {}
    },
    "firecrawl": {
      "command": "npx",
      "args": ["-y", "firecrawl-mcp"],
      "env": {
        "FIRECRAWL_API_KEY": "${FIRECRAWL_API_KEY}"
      }
    }
  }
}
```

### Agent Tool Updates

Each agent's `allowed-tools` frontmatter should be updated:

**market-agent.md**:
```yaml
allowed-tools:
  - AskUserQuestion
  - Read
  - Write
  - Glob
  - Bash
  - mcp__brave-search__search
  - mcp__crunchbase__search_companies
  - mcp__crunchbase__get_company
  - mcp__sec-edgar__search_filings
  - mcp__sec-edgar__get_financials
```

**analyze-agent.md**:
```yaml
allowed-tools:
  - AskUserQuestion
  - Read
  - Write
  - Glob
  - Bash
  - mcp__brave-search__search
  - mcp__crunchbase__search_companies
  - mcp__firecrawl__scrape
  - mcp__firecrawl__crawl
  - mcp__sec-edgar__get_financials
```

**strategy-agent.md**:
```yaml
allowed-tools:
  - AskUserQuestion
  - Read
  - Write
  - Glob
  - Bash
  - mcp__brave-search__search
  - mcp__crunchbase__search_companies
```

### Environment Variables

Add to user's shell profile or `.env`:
```bash
export BRAVE_API_KEY="your-brave-api-key"
export CRUNCHBASE_API_KEY="your-crunchbase-api-key"
export FIRECRAWL_API_KEY="your-firecrawl-api-key"
# Optional
export ALPHA_VANTAGE_API_KEY="your-alpha-vantage-key"
```

## Decisions

1. **Prioritize free-tier servers** - Most founder users are bootstrapping, minimize API costs
2. **Start with search + company data** - Brave Search and Crunchbase cover 80% of research needs
3. **Add scraping capability** - Firecrawl enables competitor website analysis without manual work
4. **SEC EDGAR for free financials** - No API key needed, valuable for public company research
5. **LinkedIn deferred** - Authentication complexity, consider for v2

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| API rate limits exceeded | Medium | Implement caching, use multiple sources |
| API keys not configured | High | Graceful degradation, clear setup docs |
| MCP server unavailable | Medium | Fallback to manual research prompts |
| Data quality issues | Medium | Cross-reference multiple sources |
| Free tier limitations | Low | Document limits, upgrade path clear |

## Implementation Steps

1. **Phase 1**: Update manifest.json with MCP server configurations
2. **Phase 2**: Update agent frontmatter with new allowed-tools
3. **Phase 3**: Create setup documentation for API key configuration
4. **Phase 4**: Add context files with usage patterns for each MCP server
5. **Phase 5**: Test agent capabilities with new tools
6. **Phase 6**: Update EXTENSION.md with new capabilities

## Context Extension Recommendations

- **Topic**: MCP server usage patterns for business research
- **Gap**: No existing context for using external data sources in founder analysis
- **Recommendation**: Create `.claude/extensions/founder/context/project/founder/tools/mcp-server-usage.md` documenting when and how to use each MCP server

## Appendix

### Search Queries Used

1. "MCP Model Context Protocol servers business market research 2026"
2. "MCP servers GitHub awesome-mcp-servers list 2026"
3. "MCP server financial data API stock market company information"
4. "MCP server competitive intelligence company research business analysis"
5. "MCP server web scraping news aggregation market trends"
6. "MCP server database search Google Sheets spreadsheet integration"
7. "MCP server Brave search web search Tavily Perplexity"
8. "MCP server LinkedIn company API business networking"
9. "MCP server Crunchbase startup funding investment data"
10. "MCP server Airtable Notion document productivity knowledge base"
11. "MCP server SEC filings EDGAR company financial statements 10K"
12. "MCP server SimilarWeb Semrush SEO analytics traffic data"
13. "MCP server email automation Gmail outreach sales CRM HubSpot"
14. "MCP server API free tier pricing authentication requirements"

### Key Documentation References

- [awesome-mcp-servers (punkpeye)](https://github.com/punkpeye/awesome-mcp-servers)
- [awesome-mcp-servers (wong2)](https://github.com/wong2/awesome-mcp-servers)
- [MCP Servers Directory](https://mcpservers.org/)
- [PulseMCP Server Directory](https://www.pulsemcp.com/servers)
- [Alpha Vantage MCP](https://mcp.alphavantage.co/)
- [Firecrawl MCP Server](https://docs.firecrawl.dev/mcp-server)
- [Brave Search MCP](https://www.pulsemcp.com/servers/brave-search)
- [SEC EDGAR MCP](https://github.com/stefanoamorelli/sec-edgar-mcp)
- [Crunchbase MCP](https://github.com/Cyreslab-AI/crunchbase-mcp-server)
- [HubSpot MCP](https://developers.hubspot.com/mcp)
- [Notion MCP](https://developers.notion.com/guides/mcp/mcp)

### MCP Ecosystem Status (March 2026)

The MCP ecosystem has matured significantly:
- Donated to Linux Foundation (Agentic AI Foundation) in December 2025
- 2026 roadmap focuses on transport scalability, enterprise readiness
- Over 8,500 MCP servers available on PulseMCP
- Major adoption by OpenAI, Google DeepMind, and enterprise tooling
